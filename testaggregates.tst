#ifdef TESTAGG
	if (!iprint)
		printf("\n\u2463****************************DEVICE:  AGGREGATES & TILES****************\n");
	if (!iprint)
		printf("DEVICE:\u2463 AGGREGATES \nDEVICE:\u2463 TILES tilex %d, tiley %d \n", tilex, tiley);
	if (!iprint)
		printf("end \u2463***********************DEVICE:  AGGREGATES & TILES*****************\n\n");
	__syncthreads();
		
	if (!iprint) {
		float Sumscratch = 0.0f;
		float maxscratch = 0.0f;
		for (int itest = 0; itest < XSCRATCH * YSCRATCH; itest++) {
			float test = Scratchpad[itest];
			Sumscratch += test;
			if (maxscratch < test)
				maxscratch = test;
			val2_scratchpad[itest] = Scratchpad[itest];  // scratchpad image validation
			if (test != 0.0f) {
				printf("\n\u2464***************************DEVICE:  SCRATCHPAD *******************\n");
				printf("DEVICE: \u2464 SCRATCH: position %d  corrected pos %d position in SCRATCH x: %d  y: %d value %5.1f \n", itest, itest - lostpixels,
						((itest - lostpixels) % XSCRATCH), ((itest - lostpixels) / XSCRATCH), test);
	/*			printf("DEVICE: \u2464 TILE: position %d  corrected pos %d  position in Tile x: %d  y: %d value %5.1f \n", itest,(itest - lostpixels),
						((itest - lostpixels) % XSCRATCH) - (dxSCR/2), ((itest - lostpixels) / YSCRATCH) - (dySCR/2), test);
				printf(
						"DEVICE: \u2464 RECONSTRUCTION: position %d  corrected pos %d  position in reconstruction x: %d  y: %d value %5.1f \n",
						itest, (itest - lostpixels), ((itest - lostpixels) % XSCRATCH) - (dxSCR/2) + tilex * XTile,
						((itest - lostpixels) / YSCRATCH) - (dySCR/2) + tiley * YTile, test);*/
			}
		}
		printf("DEVICE: \u2464 SUM SCRATCHPAD: Sum of scratchpad %5.1f Max of Scratchpad %5.1f \n", Sumscratch,
				maxscratch);
		if (!iprint)
			printf("end \u2464*******************************DEVICE:  SCRATCHPAD ********************\n\n");
	} // loop on TESTAGG
#endif
	__syncthreads();
