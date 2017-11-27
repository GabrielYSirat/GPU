#ifdef OFFSET
for (int iblockima = 0; iblockima < DD.NbLaserpertile[tileXY]; iblockima++) {
	if(!ithreads)
	printf("\u23f3 ** OFFSET:aggregx %d aggregy %d tileXY %d iblockima %d offset %d iglobal %d\n",
			aggregx, aggregy, tileXY, iblockima,*(image_to_scratchpad_offset_tile + iblockima), iglobal);
	// validé
}

__syncthreads();
#endif
