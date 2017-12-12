/*
 * big.cu
 *
 *  Created on: Jul 6, 2017
 *      Author: gabriel
 */
#include "0_Mainparameters.h"
bool biglaunch() {
	onhost.NbTilex = tile.NbTilex;
	onhost.NbTiley = tile.NbTiley;
	onhost.NbTileXY = tile.NbTileXY;
	onhost.NbTileXYD = tile.NbTileXYD;
	onhost.NbAggregx = tile.NbAggregx;
	onhost.NbAggregy = tile.NbAggregy;
	onhost.tileperaggregatex = tile.tileperaggregatex;
	onhost.tileperaggregatey = tile.tileperaggregatey;

	onhost.maxLaserintile = tile.maxLaserintile;
	onhost.blocks = tile.blocks;
	onhost.minLaserintile = tile.minLaserintile;
	onhost.Nb_LaserPositions = TA.Nb_LaserPositions;
	onhost.MaxPSF = MaxPSF;
	onhost.MaxRec = MaxRec;
	onhost.Maxmicroimages = Maxmicroimages;
	onhost.Maxdistrib = Maxdistrib;
	onhost.clockRate = clockRate;
	onhost.XTile = XTile;
	onhost.YTile = YTile;
	onhost.lostpixelsdevice = lostpixels;
	onhost.lostlinesdevice = lostlines;
	onhost.defaultoffsetedge = tile.defaultoffsetedge;
	onhost.Bconstant = tile.Bconstant;

	verbosefile << "HOST: \u24EA  \n";
	for(int itile = 0; itile < tile.NbTileXYD; itile ++) {
		onhost.NbLaserpertile[itile] = tile.NbLaserpertile[itile];
		verbosefile << "tile n° " << itile << " #laser " << onhost.NbLaserpertile[itile] << " || ";
	}
	verbosefile << endl;


	/*********************************DOCUMENT ***************************************************************/
		verbosefile << "TESTS RETURN:  " << "initialization:  " << Stepdiag[0] << ";  pPSF:  " << Stepdiag[1];
		verbosefile << ";  distrib: " << Stepdiag[2] << endl;
		verbosefile << "TESTS RETURN: laser positions: " << Stepdiag[3] << "; ROI:  " << Stepdiag[4];
		verbosefile << "; microimages:  " << Stepdiag[5] << ";  Reconstruction:  " << Stepdiag[6] << endl;
		verbosefile << "MAIN PROGRAM  **********ready for GPU computation*****************" << endl;
		verbosefile << "******************************************************************" << endl << endl;

		verbosefile << "To be transferred to device: Number of Aggregates in x:" << tile.NbAggregx << " in y:"
				<< tile.NbAggregy;
		verbosefile << "  Number of Tiles per aggregates in x:" << tile.tileperaggregatex << " in y:"
				<< tile.tileperaggregatey << endl;
		verbosefile << "To be transferred to device: Number of Tiles in x:" << tile.NbTilex << " in y:" << tile.NbTiley
				<< endl;
		verbosefile << "To be transferred to device: Max number of laser position in Tile:" << tile.maxLaserintile
				<< " min  " << tile.minLaserintile << endl << endl;
		printf("\nHOST: \u24EA Npixel %d pZOOM %d, pPSF %d\n", Npixel, pZOOM, pPSF);
		printf("HOST: \u24EA pPSF %d XDistrib %d YDistrib %d\n", pPSF, XDistrib, YDistrib);
		printf("HOST: \u24EA XSCRATCH %d YSCRATCH %d XTile %d YTile %d\n", XSCRATCH, YSCRATCH, XTile, YTile);
		printf("HOST: \u24EA Number of pixels calculated in parallel %d Number of threads used %d loop on threads %d\n\n", NThreads,
		THREADSVAL, THreadsRatio);

		/************************* for GPU ********************/
		verbosefile << "MAIN PROGRAM  ********Prepare data for GPU computation**************" << endl;
		verbosefile << "******************************************************************" << endl;	bool testbig = FALSE;
		verbosefile << "Number of laser positions " << onhost.Nb_LaserPositions << " number of tile XY " << onhost.NbTileXY
				<<  " max number of lasers per tile " << onhost.maxLaserintile << endl;

		/********************************************Launch Main loop ***************************************/
	dim3 dimBlock(tile.tileperaggregatex, tile.tileperaggregatey, Ndistrib);
	dim3 dimGrid(THREADSVAL, 1, 1);
	int sharedsize = NIMAGESPARALLEL * sizeof(int) + ASCRATCH * sizeof(float) + ADistrib * sizeof(float);

	/*********************************DOCUMENT ***************************************************************/
	verbosefile << "dimBlock  x: " << dimBlock.x << " y: " << dimBlock.y << " z: " << dimBlock.z << "  ...  ";
	verbosefile << "dimGrid  x: " << dimGrid.x << " y: " << dimGrid.y << " z: " << dimGrid.z << endl << endl;
	verbosefile << "HOST: \u24EA ************************BigLoop start   *******************************" << endl;
	verbosefile << "HOST: \u24EA ***********************************************************************" << endl;
	cout << "HOST: \u24EA ************************BigLoop start   *******************************" << endl;
	cout << "HOST: \u24EA ***********************************************************************" << endl;



	if (sharedsize > TA.sharedmemory) {
		verbosefile << "shared memory required is above the memory available" << sharedsize / 1024.0 << "KBytes" << endl;
		exit(1);
	} else
		verbosefile << "HOST: \u24EA *** SHARED MEMORY SIZE " << sharedsize / 1024.0 << " KBytes" << endl;
	// Execute the Laser positions kernel
	BigLoop<<<dimBlock, dimGrid, sharedsize>>>(onhost);
	cudaDeviceSynchronize();

	testbig = TRUE;
	return (testbig);
}

