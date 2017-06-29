
#ifndef INTERPOL_H
#define INTERPOL_H

///////////////////////////////////////////////////////////////////////////////

#include <stdint.h>

///////////////////////////////////////////////////////////////////////////////

void init_interpolator(int interpolator);

void clear();

typedef void* tex_t;
typedef enum {
	RGB888,
	RGBA8888
} TexFormat;

tex_t create_texture(
	uint16_t w,
	uint16_t h,
	TexFormat tex_format,
	const uint8_t* pixels
);

void draw_tex(
	tex_t tex,
	uint16_t src_x, uint16_t src_y, uint16_t src_w, uint16_t src_h,
	uint16_t dst_x, uint16_t dst_y, uint16_t dst_w, uint16_t dst_h
);

void delete_texture(tex_t tex);

void flush();

///////////////////////////////////////////////////////////////////////////////

#endif // INTERPOL_H
