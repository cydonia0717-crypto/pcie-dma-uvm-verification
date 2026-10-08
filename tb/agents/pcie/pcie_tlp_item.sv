typedef enum int {PCIE_MEM_RD, PCIE_MEM_WR, PCIE_CPLD, PCIE_MEM_WR_DONE} pcie_tlp_kind_e;

class pcie_tlp_item extends uvm_sequence_item;
  pcie_tlp_kind_e kind;
  bit [127:0] hdr;
  bit [255:0] data;
  bit [7:0] strb;
  longint unsigned addr;
  int unsigned byte_len;
  bit [9:0] tag;
  bit [15:0] requester_id;
  bit [15:0] completer_id;
  bit [12:0] byte_count;
  bit [6:0] lower_addr;
  bit [2:0] cpl_status;
  // Error indications with Completion Status=SC must retire the read context,
  // not be interpreted by the scoreboard as successful payload transfer.
  bit terminal_error;
  bit [3:0] rx_cpl_error;

  `uvm_object_utils(pcie_tlp_item)
  function new(string name="pcie_tlp_item"); super.new(name); endfunction

  function void decode_request(bit [127:0] h);
    bit is_4dw;
    int unsigned dw_len;
    hdr=h;
    is_4dw = h[127:125] inside {3'b001,3'b011};
    kind = h[127:125][1] ? PCIE_MEM_WR : PCIE_MEM_RD;
    dw_len = (h[105:96] == 0) ? 1024 : h[105:96];
    byte_len = dw_len*4;
    requester_id=h[95:80]; tag={2'b0,h[79:72]};
    if (is_4dw) addr={h[63:2],2'b00}; else addr={{32{1'b0}},h[63:34],2'b00};
  endfunction

  function bit [127:0] build_cpld_header();
    bit [127:0] h='0;
    int unsigned dw_len=(byte_len + lower_addr[1:0] + 3)/4;
    h[127:125]=3'b010;
    h[124:120]=5'b01010;
    h[105:96]=(dw_len==1024)?10'd0:dw_len[9:0];
    h[95:80]=completer_id;
    h[79:77]=cpl_status;
    h[75:64]=(byte_count==4096)?12'd0:byte_count[11:0];
    h[63:48]=requester_id;
    h[47:40]=tag[7:0];
    h[38:32]=lower_addr;
    return h;
  endfunction
endclass
