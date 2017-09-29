#ifdef STARTDEVICE
	if (!iprint) { 	// the condition is required to have it printed once
		printf("\nDEVICE: ************************** START *****************************\n");
		printf("DEVICE: \u23f1 Time: Start: sec %f\n", (float) time_start / CLOCKS_PER_SEC);
		printf("DEVICE: \u2460****************PARAMETERS OF MEASUREMENT *******************\n");
		printf("DEVICE: \u2460 PARAMETERS  NThreads %d Npixel %d pZOOM %d, pPSF %d\n", NThreads, Npixel, pZOOM, pPSF);
		printf("DEVICE: \u2460 PARAMETERS dimBlock  x: %d y: %d z: %d   ...   ", blockDim.x, blockDim.y, blockDim.z);
		printf("dimGrid  x: %d y: %d z: %d\n", gridDim.x, gridDim.y, gridDim.z);
		printf("DEVICE: \u2460 PARAMETERS pPSF %d XDistrib %d YDistrib %d ADistrib %d\n", pPSF, XDistrib, YDistrib, ADistrib);
		printf("DEVICE: \u2460 PARAMETERS XSCRATCH %d YSCRATCH %d XTILE %d YTILE %d\n", XSCRATCH, YSCRATCH, XTile, YTile);
		printf("DEVICE: \u2460 PARAMETERS Number of pixels calculated in parallel %d Number of threads used"
				" %d loop on threads %d\n", NThreads, THREADSVAL, THreadsRatio);
		printf("DEVICE: \u2460  TILES: XSCRATCH %d, YSCRATCH %d  ", XSCRATCH, YSCRATCH);
		printf("XTILE %d, YTILE %d\n", XTile, YTile);
		printf("DEVICE: \u2460  TILES & AGGREGATES: Number of Aggregates in x: %d in y:%d\n", DD.NbAggregx,
				DD.NbAggregy);
		printf("DEVICE: \u2460  TILES & AGGREGATES: Number of Tiles per aggregates in x: %d in y:%d\n",
				DD.tileperaggregatex, DD.tileperaggregatey);
		printf("DEVICE: \u2460  TILES & AGGREGATES: Number of Tiles in x: %d in y:%d\n", DD.NbTilex, DD.NbTiley);
		printf("DEVICE: \u2460  TILES & AGGREGATES: Max number of laser position in Tile: %d min value:%d Number of blocks %d\n",
				DD.maxLaserintile, DD.minLaserintile, DD.blocks);
		if (!iprint)
			printf("\u2460*******************************PARAMETERS OF MEASUREMENT ****************\n");
	}
	__syncthreads();
	
	DD.step++;
	if (!itb) timer = clock64();
		if (!iprint)  	// the condition is required to have it printed once
			printf( "DEVICE: \u23f1**DEVICE:  step %d   TIMING ** processing  %g from start  %g  total %g \n\n",
					DD.step, (float) (timer - time_start) / CLOCKS_PER_SEC,
					(float) (  time_start - time_init) / CLOCKS_PER_SEC,
					(float) (timer - time_init) / CLOCKS_PER_SEC);
		__syncthreads();
			if (!itb) time_start = clock64();
		__syncthreads();
	
	
#endif


