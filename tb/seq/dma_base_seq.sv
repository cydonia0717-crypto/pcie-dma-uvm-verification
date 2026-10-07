class dma_base_seq extends uvm_sequence #(dma_desc_item);
  `uvm_object_utils(dma_base_seq)
  function new(string name="dma_base_seq"); super.new(name); endfunction
  task send(dma_dir_e dir,longint unsigned pa,int unsigned ra,int unsigned len,bit[7:0] tag);
    dma_desc_item tr=dma_desc_item::type_id::create("tr"); start_item(tr); tr.dir=dir; tr.pcie_addr=pa; tr.ram_addr=ra; tr.len=len; tr.tag=tag; finish_item(tr);
  endtask
endclass
