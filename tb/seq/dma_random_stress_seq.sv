class dma_random_stress_seq extends dma_base_seq;
  `uvm_object_utils(dma_random_stress_seq)
  int unsigned num_desc=64;
  function new(string name="dma_random_stress_seq"); super.new(name); endfunction

  task body();
    dma_dir_e dir;
    longint unsigned pa;
    int unsigned ra,len,off;
    for(int i=0;i<num_desc;i++) begin
      // Alternate direction to guarantee H2C/C2H overlap while randomizing
      // length and alignment from the simulator seed.
      dir=(i[0]) ? DMA_C2H : DMA_H2C;
      len=$urandom_range(4096,1);
      off=$urandom_range(3,0);
      if(dir==DMA_H2C) begin
        pa=64'h0000_9000_0000_0000 + i*64'h2000 + off;
        ra=20'h10000 + i*'h1000 + off;
      end else begin
        pa=64'h0000_a000_0000_0000 + i*64'h2000 + off;
        ra=20'h50000 + i*'h1000 + off;
      end
      send(dir,pa,ra,len,bit'(8'h20+i));
    end
  endtask
endclass
