#importonce

/* Call this macro to include any C64 BASIC V2 program at $0801
 *
 * The argument should be a list of strings where each string
 * is one BASIC line:
 *
 * BasicProgram(List().add(
 *		@"10 PRINT \"HELLO WORLD\"",
 *		 "20 GOTO 10"
 * ))
 *
 * The tokenization algorithm is pretty much the same as the one in
 * the C64 BASIC ROM. So it even works with the abbreviation forms of 
 * the commands. 
 * 
 * This macro does not validate the BASIC program it only tokenizes it.
 * It only report errors that prevents it from being tokenized.
 *
 * If you use this macro to make a more fancy start line you will
 * have to put it _below_ the main program start label in order to allow
 * Kick Assembler to resolve the label value:
 * 
 *			*=$0900
 * start:	jmp *
 *
 * 		BasicProgram(List().add(	
 *			"4711 SYS" + toIntString(start) + " : REM CODED BY MW 2018"
 *		))
 */
.macro BasicProgram(prog) {
	*=$0801 "Basic Program"

	.var tokenized = tokenizeProgram(prog)

	.for (var line = 0 ; line < tokenized.size() ; line++) {
		// Forward link to start of nextline
		.word * + tokenized.get(line).size() + 2
		.fill tokenized.get(line).size(), tokenized.get(line).get(i)
	}

	// End of BASIC program
	.word 0

	.memblock "Basic Program End" 
}

// A function that is called by the macro to make it a bit faster
.function tokenizeProgram(prog) {
	.var tokenized = List()	// List of tokenized lines
	.const token_strings = List().add(
		"END","FOR","NEXT","DATA","INPUT#","INPUT","DIM","READ",
		"LET", "GOTO","RUN","IF","RESTORE","GOSUB","RETURN","REM",
		"STOP","ON","WAIT","LOAD","SAVE","VERIFY","DEF","POKE",
		"PRINT#","PRINT","CONT","LIST","CLR","CMD","SYS","OPEN",
		"CLOSE","GET","NEW","TAB(","TO","FN","SPC(","THEN","NOT",
		"STEP","+","-","*","/",@"\$5e","AND","OR",">","=","<","SGN",
		"INT","ABS","USR","FRE","POS","SQR","RND","LOG","EXP","COS",
		"SIN","TAN","ATN","PEEK","LEN","STR$","VAL","ASC","CHR$",
		"LEFT$","RIGHT$","MID$","GO")

	.const error0 = @"\n\nBASIC Error: Missing line number in line "
	.const error1 = @"\n\nBASIC Error: Line number too large in line "
	.const error2 = @"\n\nBASIC Error: Line "
				
	// Tokenize one line at a time
	.for (var li = 0 ; li < prog.size() ; li++) {
		.var pos = 0
		.var line = prog.get(li)
		.var line_num_found = false
		.var line_tokens = List()

		// Search to end of line number
		.while (pos < line.size() && !line_num_found) {
			.if (line.charAt(pos) >= '0' && line.charAt(pos) <= '9') {
				.eval pos++				
			} else {
				.eval line_num_found = true
			}
		}
				
		.errorif pos == 0, error0 + li + @"\n" + line + @"\n\n"

		.var line_num = line.substring(0,pos).asNumber()

		.errorif line_num > 63999, error1 + li + @"\n" + line + @"\n\n"
		
		// Eat space after line number
		.while (pos < line.size() && line.charAt(pos) == ' ') .eval pos++

		.errorif pos==line.size(), error2 + li + @" is empty\n\n"

		// Add line number
		.eval line_tokens.add(<line_num)
		.eval line_tokens.add(>line_num)

		.var special_statement = false
					
		.while (pos < line.size()) {		
			.var c = line.charAt(pos)
			.if (c == '"') {			
				// Copy string to output as it is
				.eval line_tokens.add(c)	
				.eval pos++				
				.var dcf = false
										
				.while (pos < line.size() && !dcf) {
					.eval c = line.charAt(pos)
					.eval line_tokens.add(c)
					.eval pos++
								
					.if (c == '"') .eval dcf = true
				}				
			} else .if (special_statement) {
				// Add characters without tokenization
				.eval line_tokens.add(c)
				.eval pos++				
			} else .if (c == '?') {
				// Add a print token
				.eval line_tokens.add($99)
				.eval pos++				
			} else {
				// Now check if it should be tokenized
				.var token = 0
				.var token_found = false
				.var comp_pos = 0
				
				.while (pos + comp_pos < line.size() && token < token_strings.size() && !token_found) {
					.var ts = token_strings.get(token)
					.eval c = line.charAt(pos + comp_pos) & $ff // Hack to avoid negative values

					// Make sure that the abbreviation forms also works correctly
					.if ((comp_pos == 0 ? c : (c & $7f)) == (ts.charAt(comp_pos) & $ff)) {

						.if (comp_pos == (ts.size() - 1) || c == ts.charAt(comp_pos) + 128) {
							.eval token_found = true
						} else {
							.eval comp_pos++
						}
					} else {
						.eval comp_pos = 0
						.eval token++
					}
				}									

				.eval line_tokens.add(token_found ? token + $80 : line.charAt(pos))
				.eval pos += (token_found ? comp_pos+1 : 1)

				// For DATA and REM statement avoid any further tokenization
				.if (token_found && (token == 3 || token == 15)) .eval special_statement = true
			}							
		}		
					
		// Add a line terminating zero
		.eval line_tokens.add(0)
		.eval tokenized.add(line_tokens)
	}

	.return tokenized
}
