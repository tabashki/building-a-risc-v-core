\m4_TLV_version 1d: tl-x.org
\SV
   // This code can be found in: https://github.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/risc-v_shell.tlv
   
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/warp-v_includes/1d1023ccf8e7b0a8cf8e8fc4f0a823ebb61008e3/risc-v_defs.tlv'])
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/main/lib/risc-v_shell_lib.tlv'])



   //---------------------------------------------------------------------------------
   // Test program for RV32-I (instructions are expanded from macro)
   //
   // Runs through all instructions and generates a value in each register from x5-x30
   // Then XORs each register with a unique value, such that a passing implementation
   // would result in all 1s for registers x5-x30.
   //
   m4_test_prog() 
   m4_define(['M4_MAX_CYC'], 60)
   //---------------------------------------------------------------------------------



\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
   /* verilator lint_on WIDTH */
\TLV
   
   $reset = *reset;
   
   
   // Program Counter Logic
   $next_pc[31:0] = $reset ? 32'b0 :
                    $taken_br ? $br_tgt_pc :
                    $is_jal ? $br_tgt_pc :
                    $is_jalr ? $jalr_tgt_pc :
                    $pc + 4;
   
   $pc[31:0] = >>1$next_pc;
   
   
   // Instantiate IMem ROM
   // (automatically populated with assembled instructions)
   `READONLY_MEM($pc[31:0], $$instr[31:0])
   
   
   // Opcode decoding
   // NOTE: assumes all instructions are valid RV32I and $opcode[1:0] is always 2'b11
   $opcode[6:0] = $instr[6:0];
   $is_u_instr = $opcode[6:2] ==? 5'b0x101;
   
   $is_i_instr = ($opcode[6:2] ==? 5'b0000x)
               | ($opcode[6:2] ==? 5'b001x0)
               | ($opcode[6:2] == 5'b11001);
   
   $is_r_instr = ($opcode[6:2] == 5'b01011)
               | ($opcode[6:2] ==? 5'b011x0)
               | ($opcode[6:2] == 5'b10100);
   
   $is_s_instr = $opcode[6:2] ==? 5'b0100x;
   $is_b_instr = $opcode[6:2] == 5'b11000;
   $is_j_instr = $opcode[6:2] == 5'b11011;
   
   
   // Instruction subfield extraction
   // NOTE: $funct7 is not used in the course and is skipped
   $funct3[2:0] = $instr[14:12];
   $rd[4:0] = $instr[11:7];
   $rs1[4:0] = $instr[19:15];
   $rs2[4:0] = $instr[24:20];
   
   $funct3_valid = !($is_u_instr | $is_j_instr);
   $rd_valid = !($is_s_instr | $is_b_instr);
   $rs1_valid = $funct3_valid;
   $rs2_valid = $is_r_instr | $is_s_instr | $is_b_instr;
   $imm_valid = !$is_r_instr;
   
   $imm[31:0] = $is_i_instr ? { {21{$instr[31]}}, $instr[30:20] } :
                $is_s_instr ? { {21{$instr[31]}}, $instr[30:25], $instr[11:7] } :
                $is_b_instr ? { {20{$instr[31]}}, $instr[7], $instr[30:25], $instr[11:8], 1'b0 } :
                $is_u_instr ? { $instr[31:12], 12'b0 } :
                $is_j_instr ? { {12{$instr[31]}}, $instr[19:12], $instr[20], $instr[30:21], 1'b0 } :
                32'b0; // Default
   
   $dec_bits[10:0] = {/* $funct7[5] =*/ $instr[30], $funct3, $opcode};
   
   // Branch instruction decode
   $is_jal  = $dec_bits ==? 11'bx_xxx_1101111;
   $is_jalr = $dec_bits ==? 11'bx_000_1100111;
   $is_beq  = $dec_bits ==? 11'bx_000_1100011;
   $is_bne  = $dec_bits ==? 11'bx_001_1100011;
   $is_blt  = $dec_bits ==? 11'bx_100_1100011;
   $is_bge  = $dec_bits ==? 11'bx_101_1100011;
   $is_bltu = $dec_bits ==? 11'bx_110_1100011;
   $is_bgeu = $dec_bits ==? 11'bx_111_1100011;
   
   // Load/Store instruction decode
   $is_lb  = $dec_bits ==? 11'bx_000_0000011;
   $is_lh  = $dec_bits ==? 11'bx_001_0000011;
   $is_lw  = $dec_bits ==? 11'bx_010_0000011;
   $is_lbu = $dec_bits ==? 11'bx_100_0000011;
   $is_lhu = $dec_bits ==? 11'bx_101_0000011;
   $is_sb  = $dec_bits ==? 11'bx_000_0100011;
   $is_sh  = $dec_bits ==? 11'bx_001_0100011;
   $is_sw  = $dec_bits ==? 11'bx_010_0100011;
   
   // For the purposes of the course, we ignore the load/store width, assuming
   // every load/store has WORD width and the address is naturally aligned.
   // Allows the implementation to determine the necessary operation only
   // using the opcode and the instruction type (S-type for stores).
   $is_load = $opcode == 7'b0000011;
   $is_store = $is_s_instr;
   
   // Arithmetic/Logic instruction decode
   $is_lui   = $dec_bits ==? 11'bx_xxx_0110111;
   $is_auipc = $dec_bits ==? 11'bx_xxx_0010111;
   $is_addi  = $dec_bits ==? 11'bx_000_0010011;
   $is_slti  = $dec_bits ==? 11'bx_010_0010011;
   $is_sltiu = $dec_bits ==? 11'bx_011_0010011;
   $is_xori  = $dec_bits ==? 11'bx_100_0010011;
   $is_ori   = $dec_bits ==? 11'bx_110_0010011;
   $is_andi  = $dec_bits ==? 11'bx_111_0010011;
   $is_slli  = $dec_bits ==? 11'b0_001_0010011;
   $is_srli  = $dec_bits ==? 11'b0_101_0010011;
   $is_srai  = $dec_bits ==? 11'b1_101_0010011;
   $is_add   = $dec_bits ==? 11'b0_000_0110011;
   $is_sub   = $dec_bits ==? 11'b1_000_0110011;
   $is_sll   = $dec_bits ==? 11'b0_001_0110011;
   $is_slt   = $dec_bits ==? 11'b0_010_0110011;
   $is_sltu  = $dec_bits ==? 11'b0_011_0110011;
   $is_xor   = $dec_bits ==? 11'b0_100_0110011;
   $is_srl   = $dec_bits ==? 11'b0_101_0110011;
   $is_sra   = $dec_bits ==? 11'b1_101_0110011;
   $is_or    = $dec_bits ==? 11'b0_110_0110011;
   $is_and   = $dec_bits ==? 11'b0_111_0110011;
   
   
   // Signed comparison helper sub-expression
   $src1_sign = $src1_value[31];
   $src2_sign = $src2_value[31];
   $imm_sign = $imm[31];
   $src1_src2_signs_differ = $src1_sign != $src2_sign;
   $src1_imm_signs_differ = $src1_sign != $imm_sign;
   
   // SLTU and SLTI (set if less than, unsigned) sub-results:
   $sltu_result[31:0]  = { 31'b0, $src1_value < $src2_value };
   $sltiu_result[31:0] = { 31'b0, $src1_value < $imm };
   
   // SRA and SRAI (arithmetic shift right, unsigned) sub-results:
   $sext_src1[63:0] = { {32{$src1_sign}}, $src1_value }; // sign-extended src1
   $sra_result[63:0] = $sext_src1 >> $src2_value[4:0]; // 64-bit results (will be truncated)
   $srai_result[63:0] = $sext_src1 >> $imm[4:0];
   
   // Arithmetic instruction evaluation
   $result[31:0] = $is_jal ? $pc + 32'h4 :
                   $is_jalr ? $pc + 32'h4 :
                   $is_auipc ? $pc + $imm :
                   $is_lui ? { $imm[31:12], 12'b0 } :
                   ($is_load | $is_store) ? $src1_value + $imm :
                   $is_addi ? $src1_value + $imm :
                   $is_slti ? $sltiu_result ^ {31'b0, $src1_imm_signs_differ} :
                   $is_sltiu ? $sltiu_result :
                   $is_xori ? $src1_value ^ $imm :
                   $is_ori ? $src1_value | $imm :
                   $is_andi ? $src1_value & $imm :
                   $is_slli ? $src1_value << $imm[5:0] :
                   $is_srli ? $src1_value >> $imm[5:0] :
                   $is_srai ? $srai_result[31:0] :
                   $is_add ? $src1_value + $src2_value :
                   $is_sub ? $src1_value - $src2_value :
                   $is_sll ? $src1_value << $src2_value[4:0] :
                   $is_slt ? $sltu_result ^ {31'b0, $src1_src2_signs_differ} :
                   $is_sltu ? $sltu_result :
                   $is_xor ? $src1_value ^ $src2_value :
                   $is_srl ? $src1_value >> $src2_value[4:0] :
                   $is_sra ? $sra_result[31:0] :
                   $is_or ? $src1_value | $src2_value :
                   $is_and ? $src1_value & $src2_value :
                   32'b0;
   
   // Forbid writes to the zero register
   $wr_en = $rd_valid & ($rd[4:0] != 5'b0);
   
   // Destination register data to be written back to the Register File
   $rd_data[31:0] = $is_load ? $ld_data : $result;
   
   
   // Branching logic
   $taken_br = $is_beq ? $src1_value == $src2_value :
               $is_bne ? $src1_value != $src2_value :
               $is_blt ? ($src1_value < $src2_value) ^ $src1_src2_signs_differ :
               $is_bge ? ($src1_value >= $src2_value) ^ $src1_src2_signs_differ :
               $is_bltu ? $src1_value < $src2_value :
               $is_bgeu ? $src1_value >= $src2_value :
               0'b0;
   
   $br_tgt_pc[31:0] = $pc + $imm;
   $jalr_tgt_pc[31:0] = $src1_value + $imm;
   
   
   // Suppress unused signal warnings
   `BOGUS_USE($imm_valid $is_load $is_store)
   `BOGUS_USE($is_lb $is_lh $is_lw $is_lbu $is_lhu $is_sb $is_sh $is_sw)
   
   // Assert these to end simulation (before Makerchip cycle limit).
   m4+tb() // Expands to a *passed check that x30 == 1 and the program is looping infinitely
   *failed = *cyc_cnt > M4_MAX_CYC;
   
   // Register File Macro
   m4+rf(32, 32, $reset, $wr_en, $rd[4:0], $rd_data[31:0], $rs1_valid, $rs1[4:0], $src1_value, $rs2_valid, $rs2[4:0], $src2_value)
   
   // Data Memory macro
   m4+dmem(32, 32, $reset, $result[6:2], $is_store, $src2_value[31:0], $is_load, $ld_data[31:0])
   
   m4+cpu_viz()
\SV
   endmodule
