module send(
    input           wire_clk        ,
    input           wire_rstn       ,
    
    input           wire_module_en  ,
    input [1:0]     wire_len_sel    ,
    input [1:0]     wire_speed_sel  ,
    input [7:0]     wire_ext_data   ,
    
    output          wire_cs_n       ,
    output          wire_addr       ,
    output          wire_wr_n       ,
    output          wire_rd_n       ,
    output [7:0]    wire_data       ,
    output          wire_data_sent  ,
    
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
parameter ST_WR_DLY = 4;
parameter ST_INDEX  = 5;
parameter ST_HEAD   = 6;
parameter ST_DATA   = 7;
parameter ST_END    = 8;

reg [3:0] reg_cur_state;
reg [3:0] reg_nxt_state;

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
reg [1:0]   reg_header_cnt  ;
reg [15:0]  reg_data_cnt    ;
reg [3:0]   reg_dly_cnt     ;

reg [31:0] reg_frame_cnt;

wire wire_st_chg;
assign wire_st_chg = reg_cur_state != reg_nxt_state;
assign wire_busy = reg_cur_state != ST_IDLE;
assign wire_data_sent = reg_cur_state == ST_DATA && reg_clk_cnt >= wire_div_num;

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
                                reg_nxt_state <= ST_WR_DLY;
                        end
            ST_WR_DLY:  begin
                            if(reg_clk_cnt >= wire_div_num & (&reg_dly_cnt))
                                reg_nxt_state <= ST_INDEX;
                        end
            ST_INDEX :  begin
                            if(reg_clk_cnt >= wire_div_num & reg_index_cnt == 3)
                                reg_nxt_state <= ST_HEAD;
                        end
            ST_HEAD  :  begin
                            if(reg_clk_cnt >= wire_div_num & reg_header_cnt == 3)
                                reg_nxt_state <= ST_DATA;
                        end
            ST_DATA  :  begin
                            if(reg_clk_cnt >= wire_div_num & reg_data_cnt == reg_data_len - 9)
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
        reg_header_cnt  <= 0;
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
                            reg_header_cnt  <= 0;
                            reg_data_cnt    <= 0;
                            reg_dly_cnt     <= 0;
                        end
            ST_CMD   :  begin
                            reg_cs <= 1;
                            // reg_wr <= reg_cmd_dly_cnt == 1 | reg_cmd_dly_cnt == 2;
                            reg_wr <= reg_cmd_dly_cnt != 0 & reg_cmd_dly_cnt != 7;
                            reg_addr <= (reg_cmd_dly_cnt != 0 & reg_cmd_dly_cnt != 7) | (reg_cmd_dly_cnt == 0 & reg_clk_cnt == 3) | (reg_cmd_dly_cnt == 7 & reg_clk_cnt <= 2);
                            reg_data <= 8'haa;
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
            ST_WR_DLY:  begin
                            reg_wr <= 0;
                            reg_rd <= 0;
                            if(reg_clk_cnt >= wire_div_num)
                                reg_dly_cnt <= reg_dly_cnt + 1;
                        end
            ST_INDEX :  begin
                            reg_wr <= reg_clk_cnt <= wire_div_num[2:1] & (~wire_st_chg);
							reg_data <= reg_index_cnt == 1 ? 8'h02 : 8'h00;
                            if(reg_clk_cnt >= wire_div_num) begin
                                reg_index_cnt <= reg_index_cnt + 1;
                            end
                        end
            ST_HEAD  :  begin
                            reg_wr <= reg_clk_cnt <= wire_div_num[2:1] & (~wire_st_chg);
							reg_data <= reg_header_cnt == 0 ? reg_frame_cnt[31:24] :
                                        reg_header_cnt == 1 ? reg_frame_cnt[23:16] :
                                        reg_header_cnt == 2 ? reg_frame_cnt[15:08] : reg_frame_cnt[07:00];
                            if(reg_clk_cnt >= wire_div_num) begin
                                reg_header_cnt <= reg_header_cnt + 1;
                            end
                        end
            ST_DATA  :  begin
                            reg_wr <= reg_clk_cnt <= wire_div_num[2:1] & (~wire_st_chg);
                            reg_data <= wire_ext_data;
                            reg_dly_cnt <= 0;
                            if(reg_clk_cnt >= wire_div_num)
                                reg_data_cnt <= reg_data_cnt + 1;
                                
                            if(reg_clk_cnt >= wire_div_num & reg_data_cnt == reg_data_len - 9) begin
                                reg_cs <= 0;
                                reg_wr <= 0;
                            end
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
assign wire_data = reg_data;
assign wire_addr = reg_addr;

reg reg_cs_d1;
wire wire_cs_pos;
always @(posedge wire_clk) begin
    reg_cs_d1 <= wire_cs_n;
end
assign wire_cs_pos = wire_cs_n & ~reg_cs_d1;

always @(posedge wire_clk or negedge wire_rstn) begin
    if(~wire_rstn)
        reg_frame_cnt <= 0;
    else begin
        if(wire_cs_pos & reg_burst_cnt == 0)
            reg_frame_cnt <= reg_frame_cnt + 1;
    end
end



endmodule