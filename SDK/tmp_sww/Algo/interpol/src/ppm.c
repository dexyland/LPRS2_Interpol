
#include "ppm.h"

#include <stdio.h>

void save_ppm(
	const char* file_name,
	const uint8_t* pixels,
	unsigned width,
	unsigned height
){
	FILE* f;

	f = fopen(file_name, "wb");

	// Header.
	fprintf(
		f,
		"P6\n%u %u\n255\n",
		width,
		height
	);

	// Pixels.
	fwrite(pixels, 3*width*height, 1, f);

	fclose(f);
}
