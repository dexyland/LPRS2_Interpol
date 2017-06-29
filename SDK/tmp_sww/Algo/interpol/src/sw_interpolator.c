
///////////////////////////////////////////////////////////////////////////////

#include "common.h"
#include "ppm.h"
#include <stdlib.h>

///////////////////////////////////////////////////////////////////////////////

void sw_interpolator(
	const u32* src_mem, u16 src_mem_width,
	u16 zoom_x, u16 zoom_y,
	u16 src_x, u16 src_y, u16 src_w, u16 src_h,
	u16 dst_x, u16 dst_y, u16 dst_w, u16 dst_h
) {
#if SW_EN
	u8* vga = malloc(WIDTH*HEIGHT*3);

	const int shift = 13;
	const u16 fix_one = 0x1 << shift;

	for(u16 py = 0; py < HEIGHT; py++){
		for(u16 px = 0; px < WIDTH; px++){
			u8 r, g, b;
			if(
				dst_x <= px &&
				px < dst_x+dst_w &&
				dst_y <= py &&
				py < dst_y+dst_h
			){
				u16 sx = px - dst_x;
				u16 sy = py - dst_y;
		
				//i: u16 14b.0b, zoom_x: u16 1b.14b -> x: u32 15b.13b
				u32 x = round_fix_1((src_x+sx)*zoom_x);
				u32 y = round_fix_1((src_y+sy)*zoom_y);
			
				u16 int_x = x >> shift; //int_x: u16 15b.0b
				u16 int_y = y >> shift;

				u16 diff_x = x & ((1 << shift) - 1); //diff: u16 0b.13b
				u16 diff_y = y & ((1 << shift) - 1);

				if (int_x >= src_w){
					int_x = src_w-1;
				}
				if (int_y >= src_h){
					int_y = src_h-1;
				}
			
				u8 inc_x = 1;
				if (int_x == src_w-1){
					inc_x = 0;
				}
				u8 inc_y = src_mem_width; // tex.width
				if (int_y == src_h-1){
					inc_y = 0;
				}
			
				u32 ind_A = int_y*src_mem_width + int_x;
				//src_mem_width u16 16b.0b 16b.0b = 32b.0b
				u32 ind_B = ind_A + inc_x;
				u32 ind_C = ind_A + inc_y;
				u32 ind_D = ind_B + inc_y;

				// fix_one: 1b.13b diff_x:0b.13b
				// 1b.13b*1b.13b = 1b.26b 
				u32 temp_A = (fix_one-diff_x)*(fix_one-diff_y);
				u32 temp_B = (fix_one-diff_x)*(diff_y); 
				u32 temp_C = (diff_x)*(fix_one-diff_y);
				u32 temp_D = (diff_x)*(diff_y);
				u16 A = round_fix(temp_A, shift); // 1b.26b -> 1b.13b
				u16 B = round_fix(temp_B, shift);
				u16 C = round_fix(temp_C, shift);
				u16 D = round_fix(temp_D, shift);
			
				u32 pix_A = src_mem[ind_A]; // ind_A set in phase 0, pix_A valid in phase 1.
				u32 pix_B = src_mem[ind_B]; // Phase 1
				u32 pix_C = src_mem[ind_C]; // Phase 2
				u32 pix_D = src_mem[ind_D]; // ind_D set in phase 3, pix_D valid in phase 0.
				//8b.0b * 1b.13b = 8b.13b >> 13 = 8b.0b
				r = (
					pR(pix_A)*A +
					pR(pix_B)*B +
					pR(pix_C)*C +
					pR(pix_D)*D
				) >> shift;
				g = (
					pG(pix_A)*A +
					pG(pix_B)*B +
					pG(pix_C)*C +
					pG(pix_D)*D
				) >> shift;
				b = (
					pB(pix_A)*A +
					pB(pix_B)*B +
					pB(pix_C)*C +
					pB(pix_D)*D
				) >> shift;
			}else{
				// Background.
				r = 0;
				g = 0;
				b = 0;
			}

			int idx = (py*WIDTH + px)*3;
			vga[idx + 0] = r;
			vga[idx + 1] = g;
			vga[idx + 2] = b;
		}
	}
	
	
	save_ppm("sw.ppm", vga, WIDTH, HEIGHT);

	free(vga);
#endif
}

///////////////////////////////////////////////////////////////////////////////

