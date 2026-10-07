class dma_ref_mem extends uvm_object;
  `uvm_object_utils(dma_ref_mem)
  byte unsigned host_mem[longint unsigned];
  byte unsigned dev_mem[longint unsigned];
  function new(string name="dma_ref_mem"); super.new(name); endfunction
  function byte unsigned pattern(longint unsigned a); return byte'(a[7:0]^a[15:8]^8'h5a); endfunction
  function byte unsigned host_get(longint unsigned a); if(host_mem.exists(a)) return host_mem[a]; return pattern(a); endfunction
  function byte unsigned dev_get(longint unsigned a); if(dev_mem.exists(a)) return dev_mem[a]; return pattern(a)^8'hc3; endfunction
  function void host_put(longint unsigned a,byte unsigned d); host_mem[a]=d; endfunction
  function void dev_put(longint unsigned a,byte unsigned d); dev_mem[a]=d; endfunction
  function void seed_host(longint unsigned a,int unsigned n); for(int i=0;i<n;i++) host_mem[a+i]=pattern(a+i); endfunction
  function void seed_dev(longint unsigned a,int unsigned n); for(int i=0;i<n;i++) dev_mem[a+i]=pattern(a+i)^8'hc3; endfunction
endclass
