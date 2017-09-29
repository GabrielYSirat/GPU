#ifdef 	TESTIMAPOS
		if (!iprint)
		if(!iblockima) printf("\n\u2464*******************************DEVICE:  IMAGE OFFSET ******************\n");
		if (!iprint) printf("DEVICE: \u2464 IMAGE OFFSET : image %d Offset %d    VALID %d\n", iblockima,
				*(image_to_scratchpad_offset_tile + iblockima), valid_image[iblockima]);
		if (!iprint)
			if(iblockima == NIMAGESPARALLEL) printf("\u2464*******************************DEVICE:  IMAGE OFFSET ******************\n");
		__syncthreads();
#endif
