/*
 * big.cu
 *
 *  Created on: Jul 6, 2017
 *      Author: gabriel
 */
#include "0_NewLoop.h"
bool biglaunch() {

	std::cout << "TESTS RETURN:  " << "initialization:  " << Stepdiag[0] << ";  pPSF:  " << Stepdiag[1];
	std::cout << ";  distrib: " << Stepdiag[2] << endl;
	std::cout << "TESTS RETURN: laser positions: " << Stepdiag[3] << "; ROI:  " << Stepdiag[4];
	std::cout << "; microimages:  " << Stepdiag[5] << ";  Reconstruction:  " << Stepdiag[6] << endl;
	std::cout << "MAIN PROGRAM  **********ready for GPU computation*****************" << endl;
	std::cout << "******************************************************************" << endl << endl;

	std::cout << "To be transferred to device: Number of Aggregates in x:" << tile.NbAggregx << " in y:"
			<< tile.NbAggregy;
	std::cout << "  Number of Tiles per aggregates in x:" << tile.tileperaggregatex << " in y:"
			<< tile.tileperaggregatey << endl;
	std::cout << "To be transferred to device: Number of Tiles in x:" << tile.NbTilex << " in y:" << tile.NbTiley
			<< endl;
	std::cout << "To be transferred to device: Max number of laser position in Tile:" << tile.maxLaserintile
			<< " min  " << tile.minLaserintile << endl << endl;
	printf("**************HOST: PARAMETERS OF MEASUREMENT *******************\n"
			"Npixel %d pZOOM %d, pPSF %d\n", Npixel, pZOOM, pPSF);
	printf("pPSF %d XDistrib %d YDistrib %d\n", pPSF, XDistrib, YDistrib);
	printf("XSCRATCH %d YSCRATCH %d XTile %d YTile %d\n\n", XSCRATCH, YSCRATCH, XTile, YTile);
	printf("Number of pixels calculated in parallel %d Number of threads used %d loop on threads %d\n", NThreads,
	THREADSVAL, THreadsRatio);

	/************************* for GPU ********************/
	std::cout << "MAIN PROGRAM  ********Prepare data for GPU computation**************" << endl;
	std::cout << "******************************************************************" << endl;
	onhost.NbTilex = tile.NbTilex;
	onhost.NbTiley = tile.NbTiley;
	onhost.NbTile = tile.NbTile;
	onhost.NbAggregx = tile.NbAggregx;
	onhost.NbAggregy = tile.NbAggregy;
	onhost.tileperaggregatex = tile.tileperaggregatex;
	onhost.tileperaggregatey = tile.tileperaggregatey;

	onhost.maxLaserintile = tile.maxLaserintile;
	onhost.blocks = tile.blocks;
	onhost.minLaserintile = tile.minLaserintile;
	onhost.Nb_LaserPositions = TA.Nb_LaserPositions;
	onhost.expectedmax = tile.expectedmax;
	onhost.clockRate = clockRate;
	std::cout << "HOST: \u24F3  ";
	for(int itile = 0; itile < tile.NbTile; itile ++) {
		onhost.NbLaserpertile[itile] = tile.NbLaserpertile[itile];
		printf("tile n° %d #laser %d .. ", itile, onhost.NbLaserpertile[itile]);
	}
	std::cout << endl;
//	onhost.imalimitpertile = onhost.Nb_LaserPositions - (onhost.NbTile - 1) * onhost.maxLaserintile;
	onhost.Bconstant = tile.Bconstant;
//	printf("Number of laser positions %d onhost.NbTile %d imalimitpertile %d onhost.maxLaserintile %d\n",
//			onhost.Nb_LaserPositions, onhost.NbTile, onhost.imalimitpertile, onhost.maxLaserintile);
	bool testbig = FALSE;

	dim3 dimBlock(tile.tileperaggregatex, tile.tileperaggregatey, Ndistrib);
	dim3 dimGrid(THREADSVAL, 1, 1);
	std::cout << "dimBlock  x: " << dimBlock.x << " y: " << dimBlock.y << " z: " << dimBlock.z << "  ...  ";
	std::cout << "dimGrid  x: " << dimGrid.x << " y: " << dimGrid.y << " z: " << dimGrid.z << endl << endl;

	std::cout << "HOST: \u24F3 ************************BigLoop start   *******************************" << endl;
	std::cout << "HOST: \u24F3 ***********************************************************************" << endl;

	int sharedsize = NIMAGESPARALLEL * sizeof(int) + ASCRATCH * sizeof(float) + ADistrib * sizeof(float);
/* 	int *image_to_scratchpad_offset_tile = (int *) shared;				// Offset of each image in NIMAGESPARALLEL block
	float *Scratchpad = (float *) &image_to_scratchpad_offset_tile[NIMAGESPARALLEL];   // ASCRATCH floats for Scratchpad
	float *shared_distrib = (float*) &Scratchpad[ASCRATCH]; 		    		// XDISTRIB*YDISTRIB floats for distrib
 */

	if (sharedsize > TA.sharedmemory) {
		std::cout << "shared memory required is above the memory available" << sharedsize / 1024.0 << "KBytes" << endl;
		exit(1);
	} else
		std::cout << "HOST: \u24F3 *** SHARED MEMORY SIZE " << sharedsize / 1024.0 << " KBytes" << endl;
	// Execute the Laser positions kernel
	BigLoop<<<dimBlock, dimGrid, sharedsize>>>(onhost);
	cudaDeviceSynchronize();

	testbig = TRUE;
	return (testbig);
}

