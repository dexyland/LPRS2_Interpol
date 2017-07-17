
///////////////////////////////////////////////////////////////////////////////

#include <stdio.h>

#include "interpol.h"

#include "interpol_kitten.h"

///////////////////////////////////////////////////////////////////////////////


int main() {
	init_interpolator(0);

#if 0 //DEV DEBUG
#define W 2
#define H 2
	
	uint8_t buffer[W*H*3];
	
	for(int i = 0; i < W*H*3; i++){
		buffer[i] = 0;
	}
	
	buffer[0] = 255;
	buffer[4] = 255;
	
	tex_t t = create_texture(
		W,
		H,
		RGB888,
		buffer
	);

	clear();

	draw_tex(
		t,
		0, 0, W, H,
		0, 0, W, H
	);
#else
	tex_t t = create_texture(
		interpol_kitten.width,
		interpol_kitten.height,
		RGB888,
		interpol_kitten.pixel_data
	);

	clear();

	/*draw_tex(
		t,
		0, 0, interpol_kitten.width, interpol_kitten.height,
		200, 100, interpol_kitten.width*3.5, interpol_kitten.height*1.5
	);*/
	
	draw_tex(
		t,
		0, 0, interpol_kitten.width, interpol_kitten.height,
		0, 0, interpol_kitten.width, interpol_kitten.height
	);
#endif
	
	flush();

	delete_texture(t);

	return 0;
}

///////////////////////////////////////////////////////////////////////////////
