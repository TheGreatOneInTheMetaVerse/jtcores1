wpset 0xfe8000,2,w,1,{printf "Write SCR HPOS=%04X",wpdata;g}
wpset 0xfe8002,2,w,1,{printf "Write SCR VPOS=%04X",wpdata;g}
wpset 0xfe4002,2,w,1,{printf "Write SCR BANK=%X",(wpdata&2)>>1;g}
