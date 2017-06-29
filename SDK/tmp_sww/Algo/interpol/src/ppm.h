
#ifndef PPM_H
#define PPM_H

#include <stdint.h>

void save_ppm(
	const char* file_name,
	const uint8_t* pixels,
	unsigned width,
	unsigned height
);

#endif // PPM_H
