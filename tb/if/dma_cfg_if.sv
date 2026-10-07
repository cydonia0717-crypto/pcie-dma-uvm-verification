interface dma_cfg_if(input logic clk);
  logic rst;
  logic read_enable,write_enable,ext_tag_enable,rcb_128b;
  logic [15:0] requester_id;
  logic [2:0] max_read_request_size;
  logic [2:0] max_payload_size;
  logic status_rd_busy,status_wr_busy,status_error_cor,status_error_uncor;
endinterface
