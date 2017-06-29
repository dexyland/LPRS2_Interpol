
///////////////////////////////////////////////////////////////////////////////

#include "interpol.h"
#include "common.h"

#include <stdlib.h>

///////////////////////////////////////////////////////////////////////////////
// Pointers to SW/HW pixels structures.

typedef struct {
	u16 w;
	u16 h;
	u32* pixels;
} Tex;

///////////////////////////////////////////////////////////////////////////////
// Other pixels.

static int _interpolator;

///////////////////////////////////////////////////////////////////////////////

void init_interpolator(int interpolator) {
	_interpolator = interpolator;
}

void clear() {
}

tex_t create_texture(
	uint16_t w,
	uint16_t h,
	TexFormat tex_format,
	const uint8_t* pixels
) {
	Tex* t = malloc(sizeof(Tex));
	t->w = w;
	t->h = h;
	
	if(_interpolator <= 0){
#if SW_EN
		t->pixels = malloc(w*h*4);
#endif
	}else{
#if HW_EN
		//TODO Alloc HW.
#endif
	}
	
	switch(tex_format){
	case RGB888:
		for(u16 y = 0; y < h; y++){
			for(u16 x = 0; x < w; x++){
				u32 idx = y*w + x;
				t->pixels[idx] = pRGBA(
					pixels[idx*3],
					pixels[idx*3+1],
					pixels[idx*3+2],
					0
				);
			}
		}
		break;
	}
	return (tex_t)t;
}

void draw_tex(
	tex_t tex,
	uint16_t src_x, uint16_t src_y, uint16_t src_w, uint16_t src_h,
	uint16_t dst_x, uint16_t dst_y, uint16_t dst_w, uint16_t dst_h
) {
	Tex* t = tex;
	
	// [0, 1] 1b.14b
	u16 zoom_x = round_fix_1(((u32)(src_w-1) << 15) / (dst_w-1));
	u16 zoom_y = round_fix_1(((u32)(src_h-1) << 15) / (dst_h-1));
	
	if(_interpolator == 0){
		sw_interpolator(
			t->pixels, t->w,
			zoom_x, zoom_y,
			src_x, src_y, src_w, src_h,
			dst_x, dst_y, dst_w, dst_h
		);
	}else{
		hw_interpolator(
			t->pixels, t->w,
			zoom_x, zoom_y,
			src_x, src_y, src_w, src_h,
			dst_x, dst_y, dst_w, dst_h
		);
	}
}

void delete_texture(tex_t tex) {
	if(_interpolator <= 0){
#if SW_EN
		free((Tex*)tex);
#endif
	}else{
#if HW_EN
		//TODO Dealloc HW.
#endif
	}
}

void flush() {
}

///////////////////////////////////////////////////////////////////////////////
