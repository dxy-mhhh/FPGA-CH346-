module recv(
    input           wire_clk            ,
    input           wire_rstn           ,
    
    input           wire_module_en      ,
    input [1:0]     wire_len_sel        ,
    input [1:0]     wire_speed_sel      ,
    
    output          wire_cs_n           ,
    output          wire_addr           ,
    output          wire_wr_n           ,
    output          wire_rd_n           ,
    input  [7:0]    wire_data_i         ,
    output [7:0]    wire_data_o         ,
    output          wire_data_oe        ,
    output          wire_err_flag_data  ,
    output          wire_err_flag_index ,

    output          wire_busy
);

reg  [15:0] reg_data_len    ;
wire [2 :0] wire_div_num    ;
reg  [4 :0] reg_burst_num   ;
reg  [4 :0] reg_burst_cnt   ;
reg  [15:0] reg_offset_addr ;

assign wire_div_num =   wire_speed_sel == 2'd0 ? (8 - 1) : // fclk/8
                        wire_speed_sel == 2'd1 ? (4 - 1) : // fclk/4
                                                 (2 - 1) ; // fclk/2

always @(posedge wire_clk) begin
    reg_data_len <= 516;
    // reg_data_len <= wire_len_sel == 2'd0 ? 512  :
                    // wire_len_sel == 2'd1 ? 1024 :
                    // wire_len_sel == 2'd2 ? 2048 : 4096;
end

always @(posedge wire_clk) begin
    reg_burst_num <= wire_len_sel == 2'd0 ? 16  :
                     wire_len_sel == 2'd1 ? 8   :
                     wire_len_sel == 2'd2 ? 4   : 2;
end

always @(posedge wire_clk) begin
    // reg_offset_addr <= reg_data_len * reg_burst_cnt;
    reg_offset_addr <= 516 * reg_burst_cnt;
end

//--state machine
parameter ST_IDLE   = 0;
parameter ST_CMD    = 1;
parameter ST_OFFSET = 2;
parameter ST_LEN    = 3;
parameter ST_INDEX  = 4;
parameter ST_RD_DLY = 5;
parameter ST_DATA   = 6;
parameter ST_END    = 7;

reg [2:0] reg_cur_state;
reg [2:0] reg_nxt_state;

reg         reg_cs          ;
reg         reg_wr          ;
reg         reg_rd          ;
reg         reg_addr        ;
reg [7:0]   reg_data        ;
reg [2:0]   reg_clk_cnt     ;

reg [2:0]   reg_cmd_dly_cnt ;
reg [1:0]   reg_offset_cnt  ;
reg [1:0]   reg_len_cnt     ;
reg [1:0]   reg_index_cnt   ;
reg [15:0]  reg_data_cnt    ;
reg [3:0]   reg_dly_cnt     ;

reg [31:0] reg_frame_cnt;

wire wire_st_chg;
assign wire_st_chg = reg_cur_state != reg_nxt_state;
assign wire_busy = reg_cur_state != ST_IDLE;

always @(posedge wire_clk or negedge wire_rstn) begin
    if(~wire_rstn)
        reg_cur_state <= ST_IDLE;
    else
        reg_cur_state <= reg_nxt_state;
end


always @(posedge wire_clk or negedge wire_rstn) begin
    if(~wire_rstn)
        reg_nxt_state <= ST_IDLE;
    else begin
        case(reg_cur_state)
            ST_IDLE  :  begin
                            if(wire_module_en)
                                reg_nxt_state <= ST_CMD;
                        end
            ST_CMD   :  begin
                            if(reg_clk_cnt >= wire_div_num & (&reg_cmd_dly_cnt))
                                reg_nxt_state <= ST_OFFSET;
                        end
            ST_OFFSET:  begin
                            if(reg_clk_cnt >= wire_div_num & reg_offset_cnt == 1)
                                reg_nxt_state <= ST_LEN;
                        end
            ST_LEN   :  begin
                            if(reg_clk_cnt >= wire_div_num & reg_len_cnt == 1)
                                reg_nxt_state <= ST_RD_DLY;
                        end
            ST_RD_DLY:  begin
                            if(reg_clk_cnt >= wire_div_num & (&reg_dly_cnt))
                                reg_nxt_state <= ST_INDEX;
                        end
            ST_INDEX :  begin
                            if(reg_clk_cnt >= wire_div_num & reg_index_cnt == 3)
                                reg_nxt_state <= ST_DATA;
                        end
            ST_DATA  :  begin
                            if(reg_clk_cnt >= wire_div_num & reg_data_cnt == reg_data_len - 1)
                                reg_nxt_state <= ST_END;
                        end
            ST_END   :  begin
                            if(&reg_dly_cnt)
                                reg_nxt_state <= ST_IDLE;
                        end
            default  :  reg_nxt_state <= ST_IDLE;
        endcase
    end
end

always @(posedge wire_clk or negedge wire_rstn) begin
    if(~wire_rstn)
        reg_clk_cnt <= 0;
    else begin
        if(reg_cur_state != ST_IDLE) begin
            if(reg_clk_cnt >= wire_div_num)
                reg_clk_cnt <= 0;
            else if(~wire_st_chg)
                reg_clk_cnt <= reg_clk_cnt + 1;
        end
        else 
            reg_clk_cnt <= 0;
    end
end

always @(posedge wire_clk or negedge wire_rstn) begin
    if(~wire_rstn) begin
        reg_cs          <= 0;
        reg_wr          <= 0;
        reg_rd          <= 0;
        reg_addr        <= 0;
        reg_data        <= 0;
        
        reg_cmd_dly_cnt <= 0;
        reg_offset_cnt  <= 0;
        reg_len_cnt     <= 0;
        reg_index_cnt   <= 0;
        reg_data_cnt    <= 0;
        reg_dly_cnt     <= 0;
        reg_burst_cnt   <= 0;
    end
    else begin
        case(reg_cur_state)
            ST_IDLE  :  begin
                            reg_cs          <= 0;
                            reg_wr          <= 0;
                            reg_rd          <= 0;
                            reg_addr        <= 0;
                            reg_data        <= 0;
                            
                            reg_cmd_dly_cnt <= 0;
                            reg_offset_cnt  <= 0;
                            reg_len_cnt     <= 0;
                            reg_index_cnt   <= 0;
                            reg_data_cnt    <= 0;
                            reg_dly_cnt     <= 0;
                        end
            ST_CMD   :  begin
                            reg_cs <= 1;
                            // reg_wr <= reg_cmd_dly_cnt == 1 | reg_cmd_dly_cnt == 2;
                            reg_wr <= reg_cmd_dly_cnt != 0 & reg_cmd_dly_cnt != 7;
                            reg_addr <= (reg_cmd_dly_cnt != 0 & reg_cmd_dly_cnt != 7) | (reg_cmd_dly_cnt == 0 & reg_clk_cnt == 3) | (reg_cmd_dly_cnt == 7 & reg_clk_cnt <= 2);
                            reg_data <= 8'hbb;
                            if(reg_clk_cnt >= wire_div_num)
                                reg_cmd_dly_cnt <= reg_cmd_dly_cnt + 1;
                        end
            ST_OFFSET:  begin
                            reg_wr <= reg_clk_cnt <= wire_div_num[2:1] & (~wire_st_chg);
                            reg_addr <= 0;
                            reg_data <= reg_offset_cnt == 0 ? reg_offset_addr[7:0] : reg_offset_addr[15:8];
                            if(reg_clk_cnt >= wire_div_num)
                                reg_offset_cnt <= reg_offset_cnt + 1;
                            
                            if(reg_clk_cnt >= wire_div_num & reg_offset_cnt == 1) begin
                                if(reg_burst_cnt >= reg_burst_num - 1)
                                    reg_burst_cnt <= 0;
                                else
                                    reg_burst_cnt <= reg_burst_cnt + 1;
                            end
                        end
            ST_LEN   :  begin
                            reg_wr <= reg_clk_cnt <= wire_div_num[2:1] & (~wire_st_chg);
                            reg_data <= reg_len_cnt == 0 ? reg_data_len[7:0] : reg_data_len[15:8];
                            if(reg_clk_cnt >= wire_div_num)
                                reg_len_cnt <= reg_len_cnt + 1;
                        end
            ST_RD_DLY:  begin
                            reg_wr <= 0;
                            reg_rd <= 0;
                            if(reg_clk_cnt >= wire_div_num)
                                reg_dly_cnt <= reg_dly_cnt + 1;
                        end
            ST_INDEX :  begin
                            reg_rd <= reg_clk_cnt > wire_div_num[2:1];
                            
                            if(reg_clk_cnt >= wire_div_num) begin
                                reg_index_cnt <= reg_index_cnt + 1;
                                reg_data_cnt <= reg_data_cnt + 1;
                            end
                        end
            ST_DATA  :  begin
                            reg_rd <= reg_clk_cnt > wire_div_num[2:1];
                            
                            reg_dly_cnt <= 0;
                            if(reg_clk_cnt >= wire_div_num)
                                reg_data_cnt <= reg_data_cnt + 1;
                        end
            ST_END   :  begin   
                            reg_cs <= 0;
                            reg_wr <= 0;
                            reg_rd <= 0;
                            if(reg_clk_cnt >= wire_div_num)
                                reg_dly_cnt <= reg_dly_cnt + 1;
                        end
        endcase
    end
end

assign wire_cs_n = ~reg_cs;
assign wire_wr_n = ~reg_wr;
assign wire_rd_n = ~reg_rd;
assign wire_data_o = reg_data;
assign wire_addr = reg_addr;
assign wire_data_oe = (~wire_cs_n & ~wire_wr_n);

reg reg_wr_d1;
reg reg_rd_d1;
reg reg_rd_d2;
reg reg_cs_d1;
reg [7:0] reg_data_d1;

wire wire_rd_pos;
wire wire_cs_pos;
wire [7:0] wire_data_tmp;
always @(posedge wire_clk) begin
    reg_wr_d1 <= wire_wr_n;
    reg_rd_d1 <= wire_rd_n;
    reg_rd_d2 <= reg_rd_d1;
    reg_cs_d1 <= wire_cs_n;
    reg_data_d1 <= wire_data_i;
end

assign wire_data_tmp = wire_div_num == 1 ? wire_data_i : reg_data_d1;
// assign wire_data_tmp = reg_data_d1;

// assign wire_rd_pos = wire_div_num == 0 ? ~wire_rd_n : wire_rd_n & ~reg_rd_d1;
// assign wire_rd_pos = wire_rd_n & ~reg_rd_d1;
assign wire_rd_pos = reg_rd_d1 & ~reg_rd_d2;
assign wire_cs_pos = wire_cs_n & ~reg_cs_d1;

always @(posedge wire_clk or negedge wire_rstn) begin
    if(~wire_rstn)
        reg_frame_cnt <= 0;
    else begin
        if(wire_cs_pos & reg_burst_cnt == 0)
            reg_frame_cnt <= reg_frame_cnt + 1;
    end
end

//--data check
reg reg_err_flag_data;
reg reg_err_flag_index;
always @(posedge wire_clk or negedge wire_rstn) begin
    if(~wire_rstn) begin
        reg_err_flag_data <= 0;
    end
    // else if(~wire_cs_n) begin
	else if(wire_rd_pos) begin
		if(reg_data_cnt > 4)
			reg_err_flag_data <= (reg_data_cnt[7:0] - 8'd1) != wire_data_tmp;
	end
    // end
    else
        reg_err_flag_data <= 0;
end

always @(posedge wire_clk or negedge wire_rstn) begin
    if(~wire_rstn) begin
        reg_err_flag_index <= 0;
    end
    // else if(~wire_cs_n) begin
	else if(wire_rd_pos) begin
		if(reg_data_cnt <= 4) begin
			case(reg_data_cnt[2:0])
				3'd1: reg_err_flag_index <= wire_data_tmp != 8'h00;
				3'd2: reg_err_flag_index <= wire_data_tmp != 8'h02;
				3'd3: reg_err_flag_index <= wire_data_tmp != 8'h00;
				3'd4: reg_err_flag_index <= wire_data_tmp != 8'h00;
				// 3'd1: reg_err_flag_index <= reg_frame_cnt[31:24] != wire_data_tmp;
				// 3'd2: reg_err_flag_index <= reg_frame_cnt[23:16] != wire_data_tmp;
				// 3'd3: reg_err_flag_index <= reg_frame_cnt[15:08] != wire_data_tmp;
				// 3'd4: reg_err_flag_index <= reg_frame_cnt[07:00] != wire_data_tmp;
			endcase
		end
	end
    // end
    else
        reg_err_flag_index <= 0;
end

reg reg_err_flag_led_data;
reg reg_err_flag_led_index;
always @(posedge wire_clk or negedge wire_rstn) begin
    if(~wire_rstn) begin
        reg_err_flag_led_data <= 0;
    end
    else if(reg_err_flag_data)
        reg_err_flag_led_data <= 1;
end

always @(posedge wire_clk or negedge wire_rstn) begin
    if(~wire_rstn) begin
        reg_err_flag_led_index <= 0;
    end
    else if(reg_err_flag_index)
        reg_err_flag_led_index <= 1;
end

assign  wire_err_flag_data  = reg_err_flag_led_data;
assign  wire_err_flag_index = reg_err_flag_led_index;

endmodule