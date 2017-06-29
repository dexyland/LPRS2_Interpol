
#ifndef COMMON_H
#define COMMON_H

///////////////////////////////////////////////////////////////////////////////

#include <stdint.h>

typedef unsigned int uint;
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef int8_t i8;
typedef int16_t i16;
typedef int32_t i32;

///////////////////////////////////////////////////////////////////////////////

#define SW_EN 1
#define HW_EN 0

///////////////////////////////////////////////////////////////////////////////

#if 1 //DEV DEBUG
#define WIDTH 4
#define HEIGHT 4
#else
#define WIDTH 640
#define HEIGHT 480
#endif

///////////////////////////////////////////////////////////////////////////////
// Interpolators.

void sw_interpolator(
	const u32* src_mem, u16 src_mem_width,
	u16 zoom_x, u16 zoom_y,
	u16 src_x, u16 src_y, u16 src_w, u16 src_h,
	u16 dst_x, u16 dst_y, u16 dst_w, u16 dst_h
);
void hw_interpolator(
	const u32* src_mem, u16 src_mem_width,
	u16 zoom_x, u16 zoom_y,
	u16 src_x, u16 src_y, u16 src_w, u16 src_h,
	u16 dst_x, u16 dst_y, u16 dst_w, u16 dst_h
);

///////////////////////////////////////////////////////////////////////////////

// round to nearest up
static inline u32 round_fix(u32 num, u8 shift) {
	u32 half = 0x1 << (shift-1);
	return (num + half) >> shift;
}

#define round_fix_1(num) (((num)+1) >> 1)

#define pR(pix) ((pix) & 0xff)
#define pG(pix) (((pix) >> 8) & 0xff)
#define pB(pix) (((pix) >> 16) & 0xff)
#define pRGBA(r, g, b, a) \
	(((u32)(a) << 24) | ((u32)(b) << 16) | ((u32)(g) << 8) | r)

///////////////////////////////////////////////////////////////////////////////

#endif // COMMON_H
