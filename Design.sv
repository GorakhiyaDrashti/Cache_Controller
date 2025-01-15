// Define constants
`define ADDR_WIDTH 64
`define DATA_WIDTH 32
`define L1_CACHE_SIZE 256 // Number of lines in L1
`define L2_CACHE_SIZE 1024 // Number of sets in L2
`define L2_WAYS 4         // 4-way set associative for L2
`define L2_BLOCK_SIZE 4   // Number of words per block in L2

// Calculate tag sizes
`define L1_INDEX_BITS 8  // log2(L1_CACHE_SIZE)
`define L1_TAG_BITS (`ADDR_WIDTH - `L1_INDEX_BITS - 0) // No block offset for L1
`define L2_INDEX_BITS 10 // log2(L2_CACHE_SIZE)
`define L2_BLOCK_OFFSET_BITS 2 // log2(L2_BLOCK_SIZE)
`define L2_TAG_BITS (`ADDR_WIDTH - `L2_INDEX_BITS - `L2_BLOCK_OFFSET_BITS)

module CacheInterface;
    logic clk;
    logic reset;
    logic [`ADDR_WIDTH-1:0] address;
    logic read_write;  // 0 for read, 1 for write
    logic [`DATA_WIDTH-1:0] write_data;
    logic [`DATA_WIDTH-1:0] read_data;
    logic hit;
    logic miss;
endmodule

module CacheController(
    input logic clk,
    input logic reset,
    input logic [`ADDR_WIDTH-1:0] address,
    input logic read_write,
    input logic [`DATA_WIDTH-1:0] write_data,
    output logic [`DATA_WIDTH-1:0] read_data,
    output logic hit,
    output logic miss
);

    // L1 Cache Memory
    typedef struct {
        logic valid;
        logic [`L1_TAG_BITS-1:0] tag; // Optimized tag size for L1
        logic [`DATA_WIDTH-1:0] data;
    } L1_Line;

    L1_Line L1[`L1_CACHE_SIZE-1:0];

    // L2 Cache Memory
    typedef struct {
        logic valid;
        logic [`L2_TAG_BITS-1:0] tag; 
        logic [`DATA_WIDTH-1:0] data[`L2_BLOCK_SIZE-1:0]; // L2 block contains 4 words
    } L2_Line;

    L2_Line L2[`L2_CACHE_SIZE-1:0][`L2_WAYS-1:0];
    logic [1:0] pseudo_LRU[`L2_CACHE_SIZE-1:0]; // 2-bit Pseudo-LRU bits for 4-way associative

    // Main Memory (Simplified)
    logic [`DATA_WIDTH-1:0] MainMemory [0:65535];

    logic [`L1_INDEX_BITS-1:0] index_l1;
    logic [`L1_TAG_BITS-1:0] tag_l1;
    logic [`L2_INDEX_BITS-1:0] index_l2;
    logic [`L2_TAG_BITS-1:0] tag_l2;
    logic [`L2_WAYS-1:0] hit_l2;
    logic [`L2_BLOCK_OFFSET_BITS-1:0] block_offset; // To select a word within an L2 block
    integer repl_way;
    logic local_hit;
    logic local_miss;

    assign hit = local_hit;
    assign miss = local_miss;

    // Split address into components
    assign index_l1 = address[9:2]; // L1 uses bits 2-9 for index (ignoring block offset)
    assign tag_l1 = address[`ADDR_WIDTH-1:10];
    assign index_l2 = address[11:2]; // L2 uses bits 2-11 for index
    assign tag_l2 = address[`ADDR_WIDTH-1:12];
    assign block_offset = address[1:0]; // L2 block offset (2 bits for 4 words)

    // L1 Cache Access
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            foreach (L1[i]) begin
                L1[i].valid <= 0;
            end
            foreach (L2[i, j]) begin
                L2[i][j].valid <= 0;
                pseudo_LRU[i] <= 0;
            end
        end else begin
            if (read_write == 0) begin // Read operation
                if (L1[index_l1].valid && L1[index_l1].tag == tag_l1) begin
                    read_data <= L1[index_l1].data;
                    local_hit <= 1;
                    local_miss <= 0;
                end else begin
                    // Check L2 Cache
                    hit_l2 = 0;
                    for (integer way = 0; way < `L2_WAYS; way++) begin
                        if (L2[index_l2][way].valid && L2[index_l2][way].tag == tag_l2) begin
                            read_data <= L2[index_l2][way].data[block_offset];
                            hit_l2[way] = 1;
                        end
                    end

                    if (|hit_l2) begin
                        local_hit <= 1;
                        local_miss <= 0;
                        // Load data into L1 Cache
                        L1[index_l1].valid <= 1;
                        L1[index_l1].tag <= tag_l1;
                        L1[index_l1].data <= read_data;
                    end else begin
                        // Load data from Main Memory to L2 and L1
                        read_data <= MainMemory[address];
                        L1[index_l1].valid <= 1;
                        L1[index_l1].tag <= tag_l1;
                        L1[index_l1].data <= read_data;

                        // Replace using pseudo-LRU
                        repl_way = pseudo_LRU[index_l2];
                        L2[index_l2][repl_way].valid <= 1;
                        L2[index_l2][repl_way].tag <= tag_l2;
                        for (integer i = 0; i < `L2_BLOCK_SIZE; i++) begin
                            L2[index_l2][repl_way].data[i] <= MainMemory[(address >> 2) + i];
                        end

                        // Update pseudo-LRU
                        pseudo_LRU[index_l2] <= pseudo_LRU[index_l2] + 1;

                        local_hit <= 0;
                        local_miss <= 1;
                    end
                end
            end else begin // Write operation
                if (L1[index_l1].valid && L1[index_l1].tag == tag_l1) begin
                    L1[index_l1].data <= write_data;
                    local_hit <= 1;
                    local_miss <= 0;
                end else begin
                    local_hit <= 0;
                    local_miss <= 1;
                end

                // Write-through to L2 and Main Memory
                for (integer way = 0; way < `L2_WAYS; way++) begin
                    if (L2[index_l2][way].valid && L2[index_l2][way].tag == tag_l2) begin
                        L2[index_l2][way].data[block_offset] <= write_data;
                    end
                end
                MainMemory[address] <= write_data;
            end
        end
    end
endmodule

