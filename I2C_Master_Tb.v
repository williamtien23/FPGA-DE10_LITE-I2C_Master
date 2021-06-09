`timescale 1ns/1ns

module I2C_Master_Tb ();

reg clk = 0;
reg start = 0;
reg write = 1;
reg [1:0] num_bytes = 2;
reg [6:0] address = 7'b1011000;
reg [7:0] register = 8'b11001100;
wire fifo_read;
wire dv;
wire busy;
wire sda_oen;
wire sda_o;
reg sda_i = 1;
wire scl_oen;
wire scl_o;
reg scl_i = 1;

reg [7:0] data_tx = 8'b10100000;
wire [7:0] data_rx = 0;

reg sda = 0;
reg scl = 0;


I2C_Master DUT (.Clk(clk), .Start(start), .Write(write), .Num_Bytes(num_bytes), .Address(address), .Register(register), .Buff_Next(fifo_read), .DV(dv), .Busy(busy), 
					 .I2C_SDA_OEn(sda_oen), .I2C_SDA_O(sda_o), .I2C_SDA_I(sda_i), .I2C_SCL_OEn(scl_oen), .I2C_SCL_O(scl_o), .I2C_SCL_I(scl_i),
					 .Data_Tx(data_tx), .Data_Rx(data_rx));

//I2C_Master DUT (clk, start, write, num_bytes, address, register, fifo_read, dv, busy, sda_oen, sda_o, sda_i, scl_oen, scl_o, scl_i, data_tx, data_rx);
					 
initial begin
	#50
	start = 1;
	#1000000
	start = 0;
	#200000 //flush out write
	write = 0;
	start = 1;
	#1000000
	$stop;
	$finish;
end
					 
					 
//Top level tri state behavior	
always @ (*) begin
	if(sda_oen)
		sda = sda_o;
	else
		sda = sda_i;
	if(scl_oen)
		scl = scl_o;
	else
		scl = scl_i;
end	

always @ (posedge clk) begin
	if(!write) begin
		#10000
		sda_i <= $urandom_range(0,1);
	end
end

//Fifo
always @ (posedge fifo_read) begin
	data_tx <= data_tx + 1;
end

//Clock
always
	#10 clk = ~clk;

endmodule 