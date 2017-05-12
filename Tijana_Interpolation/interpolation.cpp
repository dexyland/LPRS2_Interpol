/*
 * @author Tijana Srejic <tijana_srejic@outlook.com>
 * @license GPL
 *
 * @brief Bilinear interpolation in fixed-point.
 */

 ///////////////////////////////////////////////////////////////////////////////

#include <stdint.h>
#include <cassert>
#include <string.h>
#include <strings.h>
#include <math.h>
#include <stdio.h>

#include <iostream>
using namespace std;

///////////////////////////////////////////////////////////////////////////////

#define DEBUG(var) do{ cout << #var << " = " << var << endl; }while(0)

///////////////////////////////////////////////////////////////////////////////

typedef unsigned int uint;
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;

struct Pixel {
	u8 red;
	u8 green;
	u8 blue;

	Pixel()
		: red(0), green(0), blue(0) {
	}
	Pixel(u8 same_for_all)
		: red(same_for_all), green(same_for_all), blue(same_for_all) {
	}
};

bool operator==(const Pixel& x, const Pixel& y) {
	return x.red == y.red && x.green == y.green && x.blue == y.blue;
}

ostream& operator<<(ostream& os, const Pixel& p) {
	return os << "Pixel(" << u32(p.red) << ", " << u32(p.green) << ", " << u32(p.blue) << ")";
}

struct Rect{
	u16 y;
	u16 x;
	u16 h;
	u16 w;

	Rect(u16 y_, u16 x_, u16 h_, u16 w_)
		: y(y_), x(x_), h(h_), w(w_) {
	}
};

struct Surface {
	Rect rect;
	Pixel* mem;
	u16 mem_width;

	Surface(const Rect& rect_, Pixel* mem_, u16 mem_width_)
		: rect(rect_), mem(mem_), mem_width(mem_width_) {
	}
};



///////////////////////////////////////////////////////////////////////////////

void bilinear_interpolation_float(Surface& dst, const Surface& src) {
    unsigned int i, j, int_x, int_y;
	int ind_A, ind_B, ind_C, ind_D;
	int incX, incY;
	float x, y, diff_x, diff_y, A, B, C, D;

	float zoom_x = (float) (src.rect.w - 1) / (dst.rect.w - 1);
	float zoom_y = (float) (src.rect.h - 1) / (dst.rect.h - 1);
	assert(zoom_x <= 1);
	assert(zoom_y <= 1);
    for(i = 0; i < dst.rect.h; i++) {
        for(j = 0; j < dst.rect.w; j++) {
            y = i*zoom_y;
            x = j*zoom_x;

            int_x = floor(x);
            int_y = floor(y);

            diff_x = x - int_x;
            diff_y = y - int_y;
			
			
            if (int_x == src.rect.w-1) 
				incX = 0;
			else
				incX = 1;
			
			if (int_y == src.rect.h-1) 
				incY = 0;
			else
				incY = src.mem_width;
			

            ind_A = src.mem_width*int_y + int_x;
            ind_B = ind_A + incX;
            ind_C = ind_A + incY;
            ind_D = ind_B + incY;

            A = (1-diff_x)*(1-diff_y);
            B = (1-diff_x)*(diff_y);
            C = (diff_x)*(1-diff_y);
            D = (diff_x)*(diff_y);
				
            dst.mem[dst.mem_width*(i + dst.rect.y) + j + dst.rect.x].red = src.mem[ind_A].red * A + src.mem[ind_B].red * B +
                                                                                src.mem[ind_C].red * C + src.mem[ind_D].red * D;
            dst.mem[dst.mem_width*(i + dst.rect.y) + j + dst.rect.x].green = src.mem[ind_A].green*A + src.mem[ind_B].green*B+
                                                                                  src.mem[ind_C].green*C + src.mem[ind_D].green*D;
            dst.mem[dst.mem_width*(i + dst.rect.y) + j + dst.rect.x].blue = src.mem[ind_A].blue*A + src.mem[ind_B].blue*B+
                                                                                 src.mem[ind_C].blue*C + src.mem[ind_D].blue*D;
        }
    }
}

// round to nearest even
u32 round_even_fix(u32 num, u8 shift) {
		u32 mask = (0x1 << shift) - 1;
		u32 half = 0x1 << (shift-1);
		u32 h_num = num >> shift;
		u32 l_num =  num & mask;
		
		if (l_num > half) {
			h_num++;
		} else if (l_num == half) {
				if (h_num & 0x1) { 
					h_num++;
				}
		}
		return h_num;
}

// round to nearest up
u32 round_fix(u32 num, u8 shift) {
		u32 half = 0x1 << (shift-1);
		return (num + half) >> shift;
}

#define round_fix_1(num)  (((num)+1) >> 1)

void bilinear_interpolation_fix(Surface& dst, const Surface& src) {
        // CPU
		u16 i, j;
		// [0, 1] 1b.14b
		u16 zoom_x = round_fix_1(((u32) (src.rect.w-1) << 15) / (dst.rect.w-1));
		u16 zoom_y = round_fix_1(((u32) (src.rect.h-1) << 15) / (dst.rect.h-1));
		// GPU
		const int shift = 13;
        u16 fix_one = 0x1 << shift;
		u8 incX, incY;
        u16 diff_x, diff_y;
        u16 int_x, int_y;
        u32 ind_A, ind_B, ind_C, ind_D;
        u16 A, B, C, D;
		u32 tempA, tempB, tempC, tempD;
		    
        for(i = 0; i < dst.rect.h; i++) {
            for(j = 0; j < dst.rect.w; j++) { 
                u32 x = round_fix_1(j*zoom_x);  //i: u16 14b.0b, zoom_x: u16 1b.14b -> x: u32 15b.13b
                u32 y = round_fix_1(i*zoom_y);
				
                int_x = x >> shift; //int_x: u16 15b.0b
                int_y = y >> shift;

                diff_x = x & ((1 << shift) - 1); //diff: u16 0b.13b
                diff_y = y & ((1 << shift) - 1);

  
				if (int_x >= src.rect.w) int_x = (u16) src.rect.w-1;
                if (int_y >= src.rect.h) int_y = (u16) src.rect.h-1;					
				incX = 1;
				if (int_x == src.rect.w-1) 
					incX = 0;
				
				incY = src.mem_width;
				if (int_y == src.rect.h-1) 
					incY = 0;
				

                ind_A = (u32) (src.mem_width*int_y + int_x);
                ind_B = (u32) (ind_A + incX);                   //src.mem_width u16 16b.0b 16b.0b = 32b.0b
                ind_C = (u32) (ind_A + incY);
                ind_D = (u32) (ind_B + incY);

				tempA = (fix_one-diff_x)*(fix_one-diff_y); //fix_one: 1b.13b diff_x:0b.13b
				tempB = (fix_one-diff_x)*(diff_y);			 //res 1b.13b*1b.13b = 1b.26b -> A: 1b.13b
				tempC = (diff_x)*(fix_one-diff_y);
				tempD = (diff_x)*(diff_y);
				A = round_fix(tempA, shift);
				B = round_fix(tempB, shift);
				C = round_fix(tempC, shift);
				D = round_fix(tempD, shift);
			     
                dst.mem[dst.mem_width*(i+dst.rect.y) + j + dst.rect.x].red = (src.mem[ind_A].red * A +    src.mem[ind_B].red * B + 
																												 src.mem[ind_C].red * C + src.mem[ind_D].red * D ) >> shift;  
																												 //8b.0b * 1b.13b = 8b.13b >> 13 = 8b.0b
                dst.mem[dst.mem_width*(i+dst.rect.y) + j + dst.rect.x].green = ((src.mem[ind_A].green * A) + (src.mem[ind_B].green * B) +
																													 (src.mem[ind_C].green * C) + (src.mem[ind_D].green * D)) >> shift;
                dst.mem[dst.mem_width*(i+dst.rect.y) + j + dst.rect.x].blue = ((src.mem[ind_A].blue * A) + (src.mem[ind_B].blue * B) +
																												  (src.mem[ind_C].blue * C) + (src.mem[ind_D].blue * D)) >> shift;
            }
        }

}

///////////////////////////////////////////////////////////////////////////////

int main() {

	// h = 20, w = 10.
	Pixel float_frame[20][10];
	Pixel fix_frame[20][10];
	Pixel tex[2][8];
	for(uint y = 0; y < 2; y++){
		for(uint x = 0; x < 2; x++){
			tex[y][x] = (y*8 + x) * 10;

		}
	}
	Surface float_frame_surf(Rect(0, 0, 0, 0), reinterpret_cast<Pixel*>(&float_frame), 10);
	Surface fix_frame_surf(Rect(0, 0, 0, 0), reinterpret_cast<Pixel*>(&fix_frame), 10);
	Surface tex_surf(Rect(0, 0, 0, 0), reinterpret_cast<Pixel*>(&tex), 8);

	// Copy-blit.
	if(true){
		float_frame_surf.rect = fix_frame_surf.rect = Rect(0, 0, 2, 2);
		tex_surf.rect   = Rect(0, 0, 2, 2);

		// Clear frame.
		memset(float_frame, 0, 200);
		// Interpolate...
		bilinear_interpolation_float(float_frame_surf, tex_surf);
		// Do the check.
		for(uint y = 0; y < 2; y++){
			for(uint x = 0; x < 2; x++){
				assert(float_frame[y][x] == tex[y][x]);
			}
		}

		// Clear frame.
		memset(fix_frame, 0, 200);
		// Interpolate...
		bilinear_interpolation_fix(fix_frame_surf, tex_surf);
		// Do the check.
		for(uint y = 0; y < 2; y++){
			for(uint x = 0; x < 2; x++){
				assert(fix_frame[y][x] == tex[y][x]);
			}
		}
	}

	// Copy-blit with offset.
	if(true){
		float_frame_surf.rect = fix_frame_surf.rect = Rect(3, 1, 2, 8);
		tex_surf.rect   = Rect(0, 0, 2, 8);

		// Clear frame.
		memset(float_frame, 0, 200);
		// Interpolate...
		bilinear_interpolation_float(float_frame_surf, tex_surf);
		// Do the check.
		for(uint y = 0; y < 2; y++){
			for(uint x = 0; x < 8; x++){
				assert(float_frame[3+y][1+x] == tex[y][x]);
			}
		}

		// Clear frame.
		memset(fix_frame, 0, 200);
		// Interpolate...
		bilinear_interpolation_fix(fix_frame_surf, tex_surf);
		// Do the check.
		for(uint y = 0; y < 2; y++){
			for(uint x = 0; x < 8; x++){
				assert(fix_frame[3+y][1+x] == tex[y][x]);
			}
		}

	}

	// Stretch-blit.
	if(true){
		float_frame_surf.rect = fix_frame_surf.rect = Rect(0, 0, 4, 8);
		tex_surf.rect   = Rect(0, 0, 2, 4);

		// Clear frame.
		memset(float_frame, 0, 200);
		// Interpolate...
		bilinear_interpolation_float(float_frame_surf, tex_surf);

		// Do the check.
		assert(float_frame[0][0] == tex[0][0]);
		assert(float_frame[3][0] == tex[1][0]);
		assert(float_frame[3][7] == tex[1][3]);
		assert(float_frame[0][7] == tex[0][3]);
		// Maybe error is bigger that 0:
        //assert(abs(frame[0][7] - tex[0][3]) <= 1);

		// Clear frame.
		memset(fix_frame, 0, 200);
		// Interpolate...
		bilinear_interpolation_fix(fix_frame_surf, tex_surf);
		// Do the check.
		
		
		assert(fix_frame[0][0] == tex[0][0]);
		assert(fix_frame[3][0] == tex[1][0]);
		assert(fix_frame[3][7] == tex[1][3]);
		assert(fix_frame[0][7] == tex[0][3]);

		// Compare float and fix results.
		for(uint y = 0; y < 4; y++){
			for(uint x = 0; x < 8; x++){
				assert(float_frame[y][x] == fix_frame[y][x]);
			}
		}
		
	}

	// TODO make non-integer zoom.

	return 0;
}

///////////////////////////////////////////////////////////////////////////////
