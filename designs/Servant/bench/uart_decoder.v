module uart_decoder
  #(parameter BAUD_RATE = 115200)
   (input rx);

   localparam T = 1000000000/BAUD_RATE;

   integer i;
   reg [7:0] ch;
   reg in_escape_seq;
   reg seen_csi;
   integer max_lines;
   integer line_count;

   initial begin
      in_escape_seq = 0;
      seen_csi = 0;
      line_count = 0;

      if (!$value$plusargs("uart_max_lines=%d", max_lines)) begin
         max_lines = 0; // 0 means no limit
      end

      forever begin
         @(negedge rx);
         #(T/2) ch = 0;
         for (i=0;i<8;i=i+1)
            #T ch[i] = rx;

         // Check for escape sequence start
         if (ch == 8'h1b) begin
            in_escape_seq = 1;
            seen_csi = 0;
         end
         // If in escape sequence, look for terminating character
         else if (in_escape_seq) begin
            if (ch == 8'h5b) begin
               // This is '[' - the CSI, not a terminator
               seen_csi = 1;
            end
            else if (seen_csi && (ch >= 8'h40 && ch <= 8'h7e)) begin
               // After CSI, letters terminate the sequence
               in_escape_seq = 0;
               seen_csi = 0;
            end
            else if (!seen_csi && (ch >= 8'h40 && ch <= 8'h7e)) begin
               // Without CSI, immediate terminator
               in_escape_seq = 0;
            end
            // Otherwise stay in escape sequence (digits, ';', etc.)
         end
         // Normal character processing (not in escape sequence)
         else if (!in_escape_seq) begin
            $write("%c", ch);
            if (ch == "\n") begin
               $fflush;
               line_count = line_count + 1;
               if (max_lines > 0 && line_count >= max_lines) begin
                  $display("uart_decoder: Reached %0d lines, terminating simulation", line_count);
                  $finish;
               end
            end
         end
      end
   end
endmodule
