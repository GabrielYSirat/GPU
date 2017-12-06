/*
 * tileorganization.cu
 *
 *  Created on: Jul 3, 2017
 *      Author: gabriel
 */
#include "0_Mainparameters.h"

__managed__ int *image_to_scratchpad_offset = { 0 }, *valid_image = { 0 };
__managed__ float *image_to_scratchpad_offset_global = { 0 };
int AmaxLaserx, AmaxLasery, AminLaserx, AminLasery;
const char * MIintilefile = "results/C_microimagesintile.pgm";
const char * NIintilefile = "results/C_microimagesintile2.pgm";
float * reorganized_data;
int fullnumberoftiles,datafullsize;
__managed__ double MaxNewSimus;

bool tileorganization(void) {
	bool Lasertile = TRUE;
	int organization_x[16] = { 0, 1, 2, 3, 2, 2, 3, 3, 4, 3, 3 };
	int organization_y[16] = { 0, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3 };
	int tilex, tiley, tilenumber, ilasertile;

	filename = resourcesdirectory + "rec_image.xml";
	cudaMallocManaged(&image_to_scratchpad_offset, MAXNUMBERLASERTILE * MAXTILE * sizeof(int));
	cudaMallocManaged(&valid_image, MAXNUMBERLASERTILE * MAXTILE * sizeof(int));

	// min and max Laser positions rounded to integer of camera pixels
	AmaxLaserx = ceil(TA.maxLaserx);
	AmaxLasery = ceil(TA.maxLasery);
	AminLaserx = floor(TA.minLaserx);
	AminLasery = floor(TA.minLasery);

	/************Tiles and aggregates*******************/
	int recdeftile0x = ceil((float) TA.Nb_Cols_reconstruction / XTile);
	int recdeftile0y = ceil((float) TA.Nb_Rows_reconstruction / YTile);
	int laserdeftile0x = CEILING_POS((float )pZOOM * (AmaxLaserx - AminLaserx) / XTile);
	int laserdeftile0y = CEILING_POS((float )pZOOM * (AmaxLasery - AminLasery) / YTile);
	tile.NbTile0x = max(laserdeftile0x, recdeftile0x);
	tile.NbTile0y = max(laserdeftile0y, recdeftile0y);
	if (((AmaxLaserx - AminLaserx) > TA.Nb_Cols_reconstruction)
			|| ((AmaxLasery - AminLasery) > TA.Nb_Rows_reconstruction))
		printf(" INIT PROG \u24FA \u26A0 tiles reconstruction too small!");

	printf(" INIT PROG \u24FA AmaxLaserx %d AmaxLasery %d AminLaserx %d AminLasery %d\n", AmaxLaserx,
			AmaxLasery, AminLaserx, AminLasery);
	printf(" INIT PROG \u24FA recdeftile0x %d recdeftile0y %d laserdeftile0x %d laserdeftile0y %d\n",
			recdeftile0x, recdeftile0y, laserdeftile0x, laserdeftile0y);
	printf(" INIT PROG \u24FA Min Number of tiles x:  %d y: %d\n", tile.NbTile0x, tile.NbTile0y);

	/*************************Aggregates organization depending on MP*******/
	TA.MP_perdistrib = TA.MP / Ndistrib;
	printf(" INIT PROG \u24FA Total number of MP per distribution %d  ", TA.MP_perdistrib);
	printf("  organized as x:%d,  y:%d \n", organization_x[TA.MP_perdistrib],
			organization_y[TA.MP_perdistrib]);

	/************************Aggregates********************************************/
	tile.NbAggregx = ceil((float) tile.NbTile0x / organization_x[TA.MP_perdistrib]);
	tile.NbAggregy = ceil((float) tile.NbTile0y / organization_y[TA.MP_perdistrib]);
	printf(" INIT PROG \u24FA Number of aggregates x:%d y:%d  \n", tile.NbAggregx, tile.NbAggregy);

	/**********************************Tiles****************************************/
	if (tile.NbAggregx == 1) {
		tile.NbTilex = tile.NbTile0x;
		tile.tileperaggregatex = tile.NbTile0x;
	} else {
		tile.NbTilex = tile.NbAggregx * organization_x[TA.MP_perdistrib];
		tile.tileperaggregatex = organization_x[TA.MP_perdistrib];
	}

	if (tile.NbAggregy == 1) {
		tile.NbTiley = tile.NbTile0y;
		tile.tileperaggregatey = tile.NbTile0y;
	} else {
		tile.NbTiley = tile.NbAggregy * organization_y[TA.MP_perdistrib];
		tile.tileperaggregatey = organization_y[TA.MP_perdistrib];
	}

	tile.NbTileXY = tile.NbTilex * tile.NbTiley;
	tile.NbTileXYD = tile.NbTilex * tile.NbTiley * Ndistrib;
	fullnumberoftiles = tile.maxLaserintile * tile.NbTileXYD;
	datafullsize = fullnumberoftiles * NThreads;

	/** FUTURE: In the real application the reconstruction
	 * is created by the program and not read from a file
	 * in this case the size data will be consistent by design
	 */
	// can be improved depending on the ratio between TILE0 and TILE: minor
	TA.Nb_Cols_reconstruction = tile.NbTilex * XTile;
	TA.Nb_Rows_reconstruction = tile.NbTiley * YTile;
	tile.startx = AminLaserx; //floor(pZOOM*((AminLaserx + AmaxLaserx)/2 - (tile.NbTilex * XTile)/2));
	tile.starty = AminLasery; //floor(pZOOM*((AminLasery + AmaxLasery)/2 - (tile.NbTiley * YTile)/2));
	TA.reconstruction_size = TA.Nb_Rows_reconstruction * TA.Nb_Cols_reconstruction;
	printf(" INIT PROG \u24FA Final number of tiles x: %d y: %d distrib %d  \n", tile.NbTilex, tile.NbTiley,
			Ndistrib);
	verbosefile << " INIT PROG \u24FA Reconstruction size x: " << TA.Nb_Cols_reconstruction << " y: " << TA.Nb_Rows_reconstruction << endl;
	verbosefile << "INIT PROG \u24FA NbTileXY " << tile.NbTileXY << " NbTileXYD " << tile.NbTileXYD;
	verbosefile << "start x " << tile.startx << " y " << tile.starty <<  " MinLaser " << AminLaserx << "  " << AminLasery;
	verbosefile << "in REC pixels x: " << tile.startx * pZOOM << " y "<< tile.starty * pZOOM << endl;

	tile.NbLaserTotal = 0;
	for (int idistrib = 0; idistrib < Ndistrib; idistrib++) {
		for (int iLaser = tile.NbLaserTotal;
				iLaser < tile.NbLaserTotal + tile.Nblaserperdistribution[idistrib]; iLaser++) {
			// position in tiles, tilex and tiley and overall tile number (including distrib)
			tilex = pZOOM * (*(PosLaserx + iLaser) - tile.startx) / XTile;
			tiley = pZOOM * (*(PosLasery + iLaser) - tile.starty) / YTile;
			tilenumber = tilex + tile.NbTilex * tiley + tile.NbTilex * tile.NbTiley * idistrib;
			float deltilex = *(PosLaserx + iLaser) * pZOOM - tilex * XTile;
			float deltiley = *(PosLasery + iLaser) * pZOOM - tiley * YTile;
			float delscratchx = deltilex + (XSCRATCH - XTile) / 2;  // XSCRATCH and XTile are odd
			float delscratchy = deltiley + (YSCRATCH - YTile) / 2;  // ySCRATCH and YTile are odd
			tile.posintile[iLaser] = tile.NbLaserpertile[tilenumber]++;
			if (VERBOSE)
				printf("TILE ORG \u2479 POS IN TILE: iLaser %d,tilenumber %d tile.posintile[iLaser]  %d\n",
						iLaser, tilenumber, tile.posintile[iLaser]);
			ilasertile = tilenumber * MAXNUMBERLASERTILE + tile.posintile[iLaser];
			valid_image[ilasertile] = 1;
			image_to_scratchpad_offset[ilasertile] = *(offsetFULL + iLaser);
			tile.maxLaserintile = max(tile.maxLaserintile, tile.NbLaserpertile[tilenumber]); // acquiring the max value per tile

			// where will be this microimage in the corresponding tile if posintile is 31, and tilenumber is 8?
			//  this microimage is the microimage with index 31 (the indexes begin at 0) of tile of index 8
			// add 1 - to go to 32 - to NbLaserpertile, because we added an image

			if (VERBOSE)
				printf(
						"TILE ORG \u2479 POS IN SCRATCH: numeral %d laser pos in x %f in y: %f  tile x: %d y: %d \n"
								"TILE ORG \u24FA POS IN SCRATCH: deltile x: %f and y %f del scratch x:%f y:%f\n"
								"TILE ORG \u24FA POS IN SCRATCH: ilasertile %d SCRATCH POSITION %d\n"
								"********************ilasertile %d offset scratchpad interaction****************** %d\n",
						iLaser, *(PosLaserx + iLaser), *(PosLasery + iLaser), tilex, tiley, deltilex,
						deltiley, delscratchx, delscratchy, ilasertile,
						image_to_scratchpad_offset[ilasertile], ilasertile,
						image_to_scratchpad_offset[ilasertile]);

			if (VERBOSE)
				printf("TILE ORG \u2479 POS IN SCRATCH: image number %d tilenumber %d position in tile %d\n",
						iLaser, tilenumber, tile.posintile[iLaser]);
		}
		printf("TILE ORG \u24FA  idistrib n°%d number of laser positions in tile in distribution %d\n",
				idistrib, tile.Nblaserperdistribution[idistrib]);
		if (VERBOSE) {
			int it0 = tile.NbTilex * tile.NbTiley * idistrib;
			for (int it = it0; it < it0 + tile.NbTilex * tile.NbTiley; it++)
				printf(" \u2479 tile %d: #lasers %d ...\n", it, tile.NbLaserpertile[it]);
			printf("\n");
		}
		tile.NbLaserTotal += tile.Nblaserperdistribution[idistrib];
	}
	printf("TILE ORG \u24FA  tile.NbLaserTotal %d \n", tile.NbLaserTotal);

	for (int it1 = 0; it1 < tile.NbTileXYD; it1++) {
		if (VERBOSE)
			printf(
					"TILE ORG \u2479 Tile number %d tile in x %d tile in y %d distrib %d number of microimages %d\n",
					it1, it1 % (Ndistrib * tile.NbTiley), (it1 / tile.NbTilex) % Ndistrib,
					it1 / (tile.NbTilex * tile.NbTiley), tile.NbLaserpertile[it1]);

		tile.maxLaserintile = max(tile.maxLaserintile, tile.NbLaserpertile[it1]); // acquiring the max value per tile
		tile.minLaserintile = min(tile.minLaserintile, tile.NbLaserpertile[it1]); // acquiring the min value per tile
	}

	printf("TILE ORG \u24FA Max  %d and Min %d  Laser in tile ...   \n", tile.maxLaserintile,
			tile.minLaserintile);
	tile.maxLaserintile = CEILING_POS(((float)tile.maxLaserintile)/NIMAGESPARALLEL) * NIMAGESPARALLEL;
	tile.blocks = tile.maxLaserintile / NIMAGESPARALLEL;
	// rounded to next multiple of NIMAGESPARALLEL
	printf("TILE ORG \u24FA Max Laser in tile rounded to next multiple of NIMAGESPARALLEL  .. %d\n",
			tile.maxLaserintile);

	return (Lasertile);
}

bool initializesimusData(void) {
// Initialize new simus and Data
	fullnumberoftiles = tile.maxLaserintile * tile.NbTileXYD;
	datafullsize = fullnumberoftiles * NThreads;
	verbosefile << "TILE ORG \u2466 size simus " << datafullsize << " AminLaserx " << AminLaserx << " AminLasery " << AminLasery << endl;
	cudaMallocManaged(&new_simus, datafullsize * sizeof(float));
	cudaMallocManaged(&Data, datafullsize * sizeof(float));
	cudaMallocManaged(&Rfactor, datafullsize * sizeof(float));

	for (int ii = 0; ii < datafullsize; ii++) {
		new_simus[ii] = 0.0f;
		Data[ii] = 0.0f;
		Rfactor[ii] = 0.0f;
	}
	cudaMallocManaged(&distribvalidGPU, TA.MP * PSFZOOMSQUARE * sizeof(float));
	for (int itemp = 0; itemp < Ndistrib * PSFZOOMSQUARE; itemp++) *(distribvalidGPU + itemp) = 0.0;
	return (TRUE);
}

bool microimagesintile(void) {
	float ratioMI = 1.0 / (Maxmicroimages - Minmicroimages);
	bool micimintile = FALSE;
	reorganized_data = (float *) calloc(fullnumberoftiles*PixZoomSquare, sizeof(float));

	unsigned char *i_data = (unsigned char *) calloc(PixZoomSquare * tile.NbTileXYD * tile.maxLaserintile, sizeof(unsigned char));
	unsigned char *j_data = (unsigned char *) calloc(PixZoomSquare * tile.NbTileXYD * tile.maxLaserintile, sizeof(unsigned char));
	verbosefile << "TILE ORG \u24FA Max Laser in tile rounded to multiple NIMAGESPARALLEL  .. " << tile.maxLaserintile;
	verbosefile << endl << "TILE ORG \u24FA Max and min microimages " << Maxmicroimages << " " << Minmicroimages << endl;

	float Maxdata = 0.0f;
	for (int idistrib = 0, disdelta = 0; idistrib < Ndistrib; idistrib++, disdelta += tile.Nblaserperdistribution[idistrib])
		for (int iLaser = disdelta; iLaser < disdelta + tile.Nblaserperdistribution[idistrib]; iLaser++) {
			int tilex = pZOOM * (*(PosLaserx + iLaser) - tile.startx) / XTile;
			int tiley = pZOOM * (*(PosLasery + iLaser) - tile.starty) / YTile;
			int tilenumber = tilex + tile.NbTilex * tiley + tile.NbTilex * tile.NbTiley * idistrib;
			int ilasertile = tilenumber * tile.maxLaserintile + tile.posintile[iLaser];
			verbosefile << "TILE ORG \u247A idistrib " << idistrib << " iLaser " << iLaser << " iLasertile " << ilasertile << " tilenumber "
					<< tilenumber << " tilex " << tilex << " tiley " << tiley << " tileblock " << disdelta << endl;
			for (int ipix = 0; ipix < PixZoomSquare; ipix++) { // copy microimage to its position in the Data
				*(reorganized_data + ilasertile * PixZoomSquare + ipix) = *(zoomed_microimages + iLaser * PixZoomSquare + ipix);
				*(Data + ilasertile * NThreads + ipix) = *(reorganized_data + ilasertile * PixZoomSquare + ipix);
				i_data[ilasertile * PixZoomSquare + ipix] = 255.0 * (*(reorganized_data + ilasertile * PixZoomSquare + ipix) - Minmicroimages) * ratioMI;
				Maxdata = max(Maxdata, i_data[ilasertile * PixZoomSquare + ipix]) ;
			}
		}
	printf("Maxdata %f Nbtile XY %d NbTile XYD %d Laserintile %d\n", Maxdata, tile.NbTileXY, tile.NbTileXYD, tile.maxLaserintile);
	T4Dto2D( j_data, i_data, tile.NbTileXYD,tile.maxLaserintile,PixZoom, PixZoom);
	verbosefile << "HOST: \u277D DEVICE TEST in biginspect.cu: Path to calculated new simulations " << MIintilefile << " .....\n";
	sdkSavePGM(MIintilefile, i_data, PixZoom , tile.maxLaserintile * tile.NbTileXYD * PixZoom);
	sdkSavePGM(NIintilefile, j_data, tile.maxLaserintile * PixZoom, tile.NbTileXYD * PixZoom);

	return (micimintile);
}
