/**
	@file : Decoder_7seg.v
	@author: William Tien
	@brief : Written for common anode 7 seg. displays

**/
module Decoder_7seg (output wire [6:0] out, input [3:0] in );

assign out = (in == 4'h0) ? 7'b1000000 :
				 (in == 4'h1) ? 7'b1111001 :
				 (in == 4'h2) ? 7'b0100100 :
				 (in == 4'h3) ? 7'b0110000 :
				 (in == 4'h4) ? 7'b0011001 :
				 (in == 4'h5) ? 7'b0010010 :
				 (in == 4'h6) ? 7'b0000010 :
				 (in == 4'h7) ? 7'b1111000 :
				 (in == 4'h8) ? 7'b0000000 :
				 (in == 4'h9) ? 7'b0010000 :
				 (in == 4'hA) ? 7'b0001000 :
				 (in == 4'hB) ? 7'b0000011 :
				 (in == 4'hC) ? 7'b1000110 :
				 (in == 4'hD) ? 7'b0100001 :
				 (in == 4'hE) ? 7'b0000110 :
				 (in == 4'hF) ? 7'b0001110 :
				 8'bXXXX_XXXX;

endmodule