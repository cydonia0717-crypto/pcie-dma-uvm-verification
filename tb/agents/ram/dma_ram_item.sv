typedef enum int {RAM_READ_CMD,RAM_WRITE_CMD} dma_ram_kind_e;
class dma_ram_obs extends uvm_sequence_item;
  dma_ram_kind_e kind;
  int unsigned segment;
  int unsigned addr;
  bit [255:0] data;
  bit [31:0] be;
  `uvm_object_utils(dma_ram_obs)
  function new(string name="dma_ram_obs"); super.new(name); endfunction
endclass
