module I2C_Master (
	input Clk,
	input Start,				//Start Transfer
	input Write,				//Read or Write Transfer
	input [1:0] Num_Bytes,	//How many bytes to transfer
	input [6:0] Address,		//Slave Address
	input [7:0] Register,	//Slave Register Address
	output reg Buff_Next,	//Finished writing a byte-Buffer input for write
	output reg DV,				//Finished reading a byte-Buffer output for read
	output reg Busy,			//Finished Transfer
	

	output reg I2C_SDA_OEn,	//SDA Tristate drive control
	output I2C_SDA_O,			//SDA Tristate out - Hardwire to 0
	input I2C_SDA_I,			//SDA Tristate In
	output reg I2C_SCL_OEn,	//SCL Tristate drive control
	output I2C_SCL_O,			//SDA Tristate out - Hardwire to 0
	input I2C_SCL_I,			//SDA Tristate In - For reading Slave Busy	
	
	input [7:0] Data_Tx,		//Data to transmit over I2C
	output reg [7:0] Data_Rx		//Data received over I2C
);

//=======================================================
//  States
//=======================================================
localparam STATE_IDLE 				= 8'd0;
localparam STATE_START 				= 8'd1;
localparam STATE_ADDRESS 			= 8'd2;
localparam STATE_RW 					= 8'd3;
localparam STATE_ACK_ADDR	 		= 8'd4;
localparam STATE_REGISTER		 	= 8'd5;
localparam STATE_ACK_REG	 		= 8'd6;
localparam STATE_WRITE		 		= 8'd7;
localparam STATE_ACK_WR		 		= 8'd8;
localparam STATE_READ				= 8'd9;
localparam STATE_ACK_R		 		= 8'd10;
localparam STATE_NACK	 			= 8'd11;
localparam STATE_STOP		 		= 8'd12;

//=======================================================
//  Internal Registers
//=======================================================

reg [7:0] state = STATE_IDLE;
reg [7:0] next_state = STATE_IDLE;

reg ack = 0;

reg write_reg = 0;
reg [6:0] address_reg = 0;
reg [7:0] register_reg = 0;
reg [7:0] data_TX_reg = 0;


reg [16:0] clock_count = 0;
reg drive_pulse = 0;
reg start_stop_pulse = 0;
reg poll_pulse = 0;
reg case_pulse = 0;

//reg start;
reg [2:0] c_start = 0;
reg [7:0] c_bit = 0;
reg [7:0] c_byte = 0;

assign I2C_SDA_O = 0;
assign I2C_SCL_O = 0;

//=======================================================
//  State Machine
//	- Uses master Clk and 3 counter generated edges: drive_pulse, start_stop_pulse, poll_pulse
//	- poll_pulse aligns with SCL and sets edge timing for polling SDA
//	- drive_pulse leads SCL by 25% and drives or releases SDA line
//	- start_stop_pulse lags SCL by 25% to drive SDA low while SCL is high for start/stop condition
//=======================================================
always @ (posedge Clk) begin
	if(case_pulse)
		state <= next_state; //Only change states on SDA change timing
end

always @ (*) begin	
	case(state) //Refer to state machine diagram
		STATE_IDLE:
		begin	
			if(Start == 1)
				next_state = STATE_START;
			else
				next_state = STATE_IDLE;
		end
		
		STATE_START:
		begin
			next_state = STATE_ADDRESS;
		end
		
		STATE_ADDRESS:
		begin
			if (c_bit == 0)
				next_state = STATE_RW;
			else
				next_state = STATE_ADDRESS;
		end
		
		STATE_RW:
		begin
			next_state = STATE_ACK_ADDR;
		end
		
		STATE_ACK_ADDR:
		begin
			if (write_reg == 0 & c_start == 2)
				next_state = STATE_READ;
			else
				next_state = STATE_REGISTER;
		end

		STATE_REGISTER:
		begin
			if (c_bit == 0)
				next_state = STATE_ACK_REG;
			else
				next_state = STATE_REGISTER;
		end

		STATE_ACK_REG:
		begin
			if(write_reg == 0)
				next_state = STATE_START;
			else
				next_state = STATE_WRITE;
		end
	
		STATE_WRITE:
		begin
			if (c_bit == 0)
				next_state = STATE_ACK_WR;
			else 
				next_state = STATE_WRITE;
		end
	
		STATE_ACK_WR:
		begin
			if (c_byte == 0)
				next_state = STATE_STOP;
			else
				next_state = STATE_WRITE;
		end
		
		STATE_READ:
		begin
			if (c_bit == 0) begin
				if (c_byte == 1) //Fix this
					next_state = STATE_NACK;
				else
					next_state = STATE_ACK_R;
			end
			else
				next_state = STATE_READ;
		end
		
		STATE_ACK_R:
		begin
			next_state = STATE_READ;

		end
		
		STATE_NACK:
		begin
			next_state = STATE_STOP;
		end
		
		STATE_STOP:
		begin
			next_state <= STATE_IDLE;
		end
		
		default: next_state <= STATE_IDLE;
		
	endcase
end


always @ (posedge Clk) begin

	case(state)
		//==================================
		// Idle State - Register Inputs on Start
		STATE_IDLE:
		begin
			ack <= 0;
			Busy <= 0;
			c_start = 0;
			c_byte <= Num_Bytes;
			write_reg <= Write;
			address_reg <= Address;
			register_reg <= Register;	
			I2C_SDA_OEn <= 0; 
		end
		
		//==================================
		// Drive SDA - Assert (Logic Low) Start Bit While SCL High
		STATE_START:
		begin
			if(start_stop_pulse) begin	
				c_bit <= 7;
				c_start = c_start + 1;
				I2C_SDA_OEn <= 1;
				Busy <= 1;
				ack <= 0;
			end
		end
		
		//==================================
		// Drive SDA - Address, MSB First
		STATE_ADDRESS:
		begin
			if(drive_pulse) begin
				if(address_reg[c_bit-1]) //Output
					I2C_SDA_OEn <= 0; //Pull-up pulls high
				else
					I2C_SDA_OEn <= 1; //Drive low
				c_bit <= c_bit - 1;
			end
		end
		
		//==================================
		// Drive SDA - Set Read/Write Bit
		STATE_RW:
		begin
			if(drive_pulse) begin
				if(write_reg) begin
					I2C_SDA_OEn <= 1; //Drive low (I2C-Low sets write)
					Buff_Next <= 1;
					data_TX_reg <= Data_Tx;
				end
				else begin
					if(c_start == 1)
						I2C_SDA_OEn <= 1;
					else
						I2C_SDA_OEn <= 0; //Pull-up pulls high for read
				end
			end
		end
		
		//==================================
		// Poll SDA - Slave Acknowledge Address
		STATE_ACK_ADDR:
		begin
			if(drive_pulse) begin
				I2C_SDA_OEn <= 0; //Release line
				c_bit <= 8;
			end
			if(poll_pulse) begin
				ack <= I2C_SDA_I; //Poll SDA Line
			end
		end

		//==================================
		// Drive SDA - Select Register	
		STATE_REGISTER:
		begin
			if(drive_pulse) begin
				if (register_reg[c_bit-1]) //Output
					I2C_SDA_OEn <= 0; //Pull-up pulls high
				else
					I2C_SDA_OEn <= 1; //Drive low
				c_bit <= c_bit - 1;
				ack <= 0;
			end
		end

		//==================================
		// POLL SDA - Same Output as ACK_ADDR		
		STATE_ACK_REG:
		begin
			if(drive_pulse) begin
				I2C_SDA_OEn <= 0; //Release line
				c_bit <= 8;
			end
			if(poll_pulse) begin
				ack <= I2C_SDA_I; //Poll SDA Line
			end
		end

		//==================================
		// Drive SDA - Write Byte Of Data		
		STATE_WRITE:
		begin
			if(drive_pulse) begin
				if (data_TX_reg[c_bit-1]) //Output
					I2C_SDA_OEn <= 0; //Pull-up pulls high
				else
					I2C_SDA_OEn <= 1; //Drive low
				c_bit <= c_bit - 1;
				Buff_Next <= 0;
				ack <= 0;
			end
		end

		//==================================
		// POLL SDA - Slave Acknowledge Byte Written		
		STATE_ACK_WR:
		begin
			if(drive_pulse) begin
				if(c_byte != 0) begin
					c_byte <= c_byte - 1;
					Buff_Next <= 1;
					data_TX_reg <= Data_Tx;
				end
				I2C_SDA_OEn <= 0; //Release line
				c_bit <= 8;
			end
			if(poll_pulse) begin
				ack <= I2C_SDA_I; //Poll SDA Line
			end
		end
		
		//==================================
		// POLL SDA - Read Byte Of Data
		STATE_READ:
		begin
			if(drive_pulse) begin
				I2C_SDA_OEn <= 0; //Release line
			end
			if(poll_pulse) begin
				Data_Rx[c_bit-1] <= I2C_SDA_I; //Poll SDA Line
				c_bit <= c_bit - 1;
			end
		end
		
		//==================================
		// Drive SDA - Master Acknowledge Byte Read
		STATE_ACK_R:
		begin
			if(drive_pulse) begin
				DV <= 1;
				I2C_SDA_OEn <= 1;
				c_bit <= 8;
				c_byte <= c_byte - 1;
			end
		end
		
		//==================================
		// Drive SDA - Master No Acknowledge Ends Read	
		STATE_NACK:
		begin
			if(drive_pulse) begin
				DV <= 1;
				I2C_SDA_OEn <= 0;
				c_byte <= c_byte - 1;
			end
		end
		
		//==================================
		// Drive SDA - Assert End Condition	
		STATE_STOP:
		begin
			if(drive_pulse) begin
				Buff_Next <= 0;
				DV <= 0;
				I2C_SDA_OEn <= 1;
			end
			if(start_stop_pulse)
				I2C_SDA_OEn <= 0;
		end
		
	endcase
end


//=======================================================
//  I2C Timing Signal Generation
//=======================================================
always @ (posedge Clk) begin
	//counter block
	if(clock_count == 500)
		clock_count <= 1;
	else
		clock_count <= clock_count+1;
	//timings	
	if(clock_count == 125) begin
		drive_pulse <= 1;
	end
	else if(clock_count == 250) begin
		poll_pulse <=1;
		I2C_SCL_OEn <= 0;
	end
	else if(clock_count == 375) begin
		start_stop_pulse <= 1;
	end
	else if(clock_count == 500) begin
		case_pulse <= 1;
		I2C_SCL_OEn <= 1;
	end
	else begin
		drive_pulse <= 0;
		poll_pulse <= 0;
		start_stop_pulse <= 0;
		case_pulse <= 0;
	end	
end

endmodule
