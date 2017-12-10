/*
 * tileorganization.cu
 *
 *  Created on: Jul 3, 2017
 *      Author: gabriel
 */
#include "0_Mainparameters.h"

__managed__ int *image_to_scratchpad_offset = { 0 }, *valid_image = { 0 };
const char * MIintilefile = "results/C_microimagesintile.pgm", *NIintilefile =
		"results/C_microimagesintile2.pgm";
float * reorganized_data;
int fullnumberoflasers, datafullsize;
int organization_x[16] = { 0, 1, 2, 3, 2, 2, 3, 3, 4, 3, 3 };
int organization_y[16] = { 0, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3 };

bool tileorganization(void) {
	bool Lasertile = TRUE;
	int tilex, tiley, tilenumber, ilasertile, nblasertile;
	filename = resourcesdirectory + "rec_image.xml";

	/************Tiles and aggregates*******************/
	int recdeftile0x = ceil((float) TA.Nb_Cols_reconstruction / XTile);
	int recdeftile0y = ceil((float) TA.Nb_Rows_reconstruction / YTile);
	int laserdeftile0x = CEILING_POS((float )pZOOM * (TA.AmaxLaserx - TA.AminLaserx) / XTile);
	int laserdeftile0y = CEILING_POS((float )pZOOM * (TA.AmaxLasery - TA.AminLasery) / YTile);
	tile.NbTile0x = max(laserdeftile0x, recdeftile0x);
	tile.NbTile0y = max(laserdeftile0y, recdeftile0y);
	if (((TA.AmaxLaserx - TA.AminLaserx) > TA.Nb_Cols_reconstruction)
			|| ((TA.AmaxLasery - TA.AminLasery) > TA.Nb_Rows_reconstruction))
		printf(" INIT PROG \u24FA \u26A0 tiles size bigger then XML parameters!");

	verbosefile << " INIT PROG \u24FA Amax x " << TA.AmaxLaserx << "  Amax y: " << TA.AmaxLasery
			<< "  Amin x: " << TA.AminLaserx << "  Amin y: " << TA.AminLasery << endl;
	verbosefile << " INIT PROG \u24FA recdeftile0x: " << recdeftile0x << " y: " << recdeftile0y;
	verbosefile << " laserdeftile0x: " << laserdeftile0x << " y: " << laserdeftile0y << endl;
	verbosefile << " INIT PROG \u24FA Min (not final!!) Number of tiles x: " << tile.NbTile0x << " y: "
			<< tile.NbTile0y << endl;

	/*************************Aggregates organization depending on MP*******/
	TA.MP_perdistrib = TA.MP / Ndistrib;
	printf("\n INIT PROG \u24FA Total number of MP per distribution %d  ", TA.MP_perdistrib);
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
	fullnumberoflasers = tile.maxLaserintile * tile.NbTileXYD;
	datafullsize = fullnumberoflasers * NThreads;

	if (NOVERBOSE)
		printf("TEST full number of lasers %d tile.maxLaserintile %d tile.NbTileXYD %d\n", fullnumberoflasers,
				tile.maxLaserintile, tile.NbTileXYD);

	cudaMallocManaged(&image_to_scratchpad_offset, fullnumberoflasers * sizeof(int));
	cudaMallocManaged(&valid_image, fullnumberoflasers * sizeof(int));
	/** initialization of the offset to the edge of the scratchpad for all images
	 *
	 */

	int defaultoffsetcenter = dySCR / 2 * XSCRATCH + dxSCR / 2 + lostpixels;
	int defaultoffsetedge = defaultoffsetcenter - (XSCRATCH + 1) * PSFZoomo2;
	verbosefile << " initialization of offset values for " << Ndistrib << " distributions and "
			<< tile.maxLaserintile << " lasers per distribution" << " full numberof lasers "
			<< fullnumberoflasers << endl;
	verbosefile << " default offset value is at center: " << defaultoffsetcenter << "  at edge "
			<< defaultoffsetedge << endl;
	for (int idistrib = 0; idistrib < Ndistrib; idistrib++)
		for (int iLaser = 0; iLaser < fullnumberoflasers; iLaser++)
			*(image_to_scratchpad_offset + iLaser) = defaultoffsetedge;

	/** FUTURE: In the real application the reconstruction
	 * is created by the program and not read from a file
	 * in this case the size data will be consistent by design
	 */
	// can be improved depending on the ratio between TILE0 and TILE: minor
	TA.Nb_Cols_reconstruction = tile.NbTilex * XTile;
	TA.Nb_Rows_reconstruction = tile.NbTiley * YTile;
	tile.startxdomain = TA.AminLaserx; //floor(pZOOM*((AminLaserx + AmaxLaserx)/2 - (tile.NbTilex * XTile)/2));
	tile.startydomain = TA.AminLasery; //floor(pZOOM*((AminLasery + AmaxLasery)/2 - (tile.NbTiley * YTile)/2));
	TA.reconstruction_size = TA.Nb_Rows_reconstruction * TA.Nb_Cols_reconstruction;
	printf(" INIT PROG \u24FA Final number of tiles x: %d y: %d distrib %d  \n\n", tile.NbTilex, tile.NbTiley,
			Ndistrib);
	verbosefile << " INIT PROG \u24FA Reconstruction size x: " << TA.Nb_Cols_reconstruction << " y: "
			<< TA.Nb_Rows_reconstruction << endl;
	verbosefile << "INIT PROG \u24FA NbTileXY " << tile.NbTileXY << " NbTileXYD " << tile.NbTileXYD;
	verbosefile << " start x " << tile.startxdomain << " y " << tile.startydomain << " MinLaser x "
			<< TA.AminLaserx << " MinLaser y " << TA.AminLasery;
	verbosefile << " in REC pixels x: " << tile.startxdomain * pZOOM << " y " << tile.startydomain * pZOOM
			<< endl;

	nblasertile = 0;
	for (int idistrib = 0; idistrib < Ndistrib; idistrib++) {
		for (int iLaser = nblasertile; iLaser < nblasertile + tile.Nblaserperdistribution[idistrib];
				iLaser++) {
			// position in tiles, tilex and tiley and overall tile number (including distrib)
			tilex = pZOOM * (*(PosLaserx + iLaser) - tile.startxdomain) / XTile;
			tiley = pZOOM * (*(PosLasery + iLaser) - tile.startydomain) / YTile;
			tilenumber = tilex + tile.NbTilex * tiley + tile.NbTilex * tile.NbTiley * idistrib;
			float deltilex = *(PosLaserx + iLaser) * pZOOM - tilex * XTile;
			float deltiley = *(PosLasery + iLaser) * pZOOM - tiley * YTile;
			float delscratchx = deltilex + (XSCRATCH - XTile) / 2;  // XSCRATCH and XTile are odd
			float delscratchy = deltiley + (YSCRATCH - YTile) / 2;  // ySCRATCH and YTile are odd
			tile.posintile[iLaser] = tile.NbLaserpertile[tilenumber]++;
				ilasertile = tilenumber * tile.maxLaserintile + tile.posintile[iLaser];
			valid_image[ilasertile] = 1;

			if (NOVERBOSE)
			printf("TILE ORG \u24FA POS IN TILE: iLaser %d,tilenumber %d tile.posintile[iLaser]  %d A ilasertile %d valid %d\n",
					iLaser, tilenumber, tile.posintile[iLaser], ilasertile, valid_image[ilasertile]);
			image_to_scratchpad_offset[ilasertile] = *(offsetFULL + iLaser);
			tile.maxLaserintile = max(tile.maxLaserintile, tile.NbLaserpertile[tilenumber]); // acquiring the max value per tile

			// where will be this microimage in the corresponding tile if posintile is 31, and tilenumber is 8?
			//  this microimage is the microimage with index 31 (the indexes begin at 0) of tile of index 8
			// add 1 - to go to 32 - to NbLaserpertile, because we added an image

			if (NOVERBOSE)
				printf("TILE ORG \u24FA POS IN SCRATCH: numeral %d laser pos in x %f in y: %f  tile x: %d y: %d \n"
								"TILE ORG \u24FA POS IN SCRATCH: deltile x: %f and y %f del scratch x:%f y:%f\n"
								"TILE ORG \u24FA POS IN SCRATCH: ilasertile %d SCRATCH POSITION %d\n"
								"********************ilasertile %d offset scratchpad interaction****************** %d\n",
						iLaser, *(PosLaserx + iLaser), *(PosLasery + iLaser), tilex, tiley, deltilex,
						deltiley, delscratchx, delscratchy, ilasertile,
						image_to_scratchpad_offset[ilasertile], ilasertile,
						image_to_scratchpad_offset[ilasertile]);

			if (NOVERBOSE)
				printf("TILE ORG \u24FA POS IN SCRATCH: image number %d tilenumber %d position in tile %d\n",
						iLaser, tilenumber, tile.posintile[iLaser]);
		}

		verbosefile << " TILE ORG \u24FA  idistrib n°" << idistrib
				<< " number of laser positions in tile in distribution "
				<< tile.Nblaserperdistribution[idistrib] << " number of tiles in distribution "
				<< tile.NbTileXY << endl;
		int it0 = tile.NbTilex * tile.NbTiley * idistrib;
		for (int it = it0; it < it0 + tile.NbTilex * tile.NbTiley; it++)
			verbosefile << " \u24FA tile " << it << ": #lasers " << tile.NbLaserpertile[it];
		verbosefile << endl;
		nblasertile += tile.Nblaserperdistribution[idistrib];
	}
	verbosefile << "TILE ORG \u24FA  nblasertile " << nblasertile << endl;
	verbosefile << endl << "images offset" << endl << endl;
	for (int iii = 0; iii < tile.maxLaserintile * tile.NbTileXYD; iii++)
		if (image_to_scratchpad_offset[iii] != defaultoffsetedge)
			verbosefile << " position " << image_to_scratchpad_offset[iii] << " @ " << iii << " | ";
	verbosefile << endl;

	for (int it1 = 0; it1 < tile.NbTileXYD; it1++) {
		if (NOVERBOSE)
			printf(
					"TILE ORG \u24FA Tile number %d tile in x %d tile in y %d distrib %d number of microimages %d\n",
					it1, it1 % (Ndistrib * tile.NbTiley), (it1 / tile.NbTilex) % Ndistrib,
					it1 / (tile.NbTilex * tile.NbTiley), tile.NbLaserpertile[it1]);

		tile.maxLaserintile = max(tile.maxLaserintile, tile.NbLaserpertile[it1]); // acquiring the max value per tile
		tile.minLaserintile = min(tile.minLaserintile, tile.NbLaserpertile[it1]); // acquiring the min value per tile
	}

	verbosefile << " TILE ORG \u24FA Max  " << tile.maxLaserintile << " and Min " << tile.minLaserintile;
	tile.maxLaserintile = CEILING_POS(((float)tile.maxLaserintile)/NIMAGESPARALLEL) * NIMAGESPARALLEL;
	tile.blocks = tile.maxLaserintile / NIMAGESPARALLEL;
	// rounded to next multiple of NIMAGESPARALLEL
	verbosefile << " Max Laser in tile rounded to next multiple of NIMAGESPARALLEL  .." << tile.maxLaserintile
			<< " \n";
	return (Lasertile);
}

bool initializesimusData(void) {
// Initialize new simus and Data
	fullnumberoflasers = tile.maxLaserintile * tile.NbTileXYD;
	datafullsize = fullnumberoflasers * NThreads;
	verbosefile << "TILE ORG \u24FB size simus " << datafullsize << " AminLaserx " << TA.AminLaserx
			<< " AminLasery " << TA.AminLasery << endl;
	cudaMallocManaged(&new_simus, datafullsize * sizeof(float));
	cudaMallocManaged(&Data, datafullsize * sizeof(float));
	cudaMallocManaged(&Rfactor, datafullsize * sizeof(float));

	for (int ii = 0; ii < datafullsize; ii++) {
		new_simus[ii] = 0.0f;
		Data[ii] = 0.0f;
		Rfactor[ii] = 0.0f;
	}
	cudaMallocManaged(&distribvalidGPU, TA.MP * PSFZOOMSQUARE * sizeof(float));
	for (int itemp = 0; itemp < Ndistrib * PSFZOOMSQUARE; itemp++)
		*(distribvalidGPU + itemp) = 0.0;
	return (TRUE);
}

bool microimagesintile(void) {
	float ratioMI = 1.0 / (Maxmicroimages - Minmicroimages);
	bool micimintile = FALSE;
	reorganized_data = (float *) calloc(fullnumberoflasers * PixZoomSquare, sizeof(float));

	unsigned char *i_data = (unsigned char *) calloc(PixZoomSquare * tile.NbTileXYD * tile.maxLaserintile,
			sizeof(unsigned char));
	unsigned char *j_data = (unsigned char *) calloc(PixZoomSquare * tile.NbTileXYD * tile.maxLaserintile,
			sizeof(unsigned char));
	verbosefile << "TILE ORG \u24FB Max Laser in tile rounded to multiple NIMAGESPARALLEL  .. "
			<< tile.maxLaserintile;
	verbosefile << endl << "TILE ORG \u24FB Max and min microimages " << Maxmicroimages << " "
			<< Minmicroimages << endl;

	float Maxdata = 0.0f;
	for (int idistrib = 0, disdelta = 0; idistrib < Ndistrib;
			idistrib++, disdelta += tile.Nblaserperdistribution[idistrib])
		for (int iLaser = disdelta; iLaser < disdelta + tile.Nblaserperdistribution[idistrib]; iLaser++) {
			int tilex = pZOOM * (*(PosLaserx + iLaser) - tile.startxdomain) / XTile;
			int tiley = pZOOM * (*(PosLasery + iLaser) - tile.startydomain) / YTile;
			int tilenumber = tilex + tile.NbTilex * tiley + tile.NbTilex * tile.NbTiley * idistrib;
			int ilasertile = tilenumber * tile.maxLaserintile + tile.posintile[iLaser];
			verbosefile << "TILE ORG \u24FA idistrib " << idistrib << " iLaser " << iLaser << " iLasertile "
					<< ilasertile << " tilenumber " << tilenumber << " tilex " << tilex << " tiley " << tiley
					<< " tileblock " << disdelta << endl;
			for (int ipix = 0; ipix < PixZoomSquare; ipix++) { // copy microimage to its position in the Data
				*(reorganized_data + ilasertile * PixZoomSquare + ipix) = *(zoomed_microimages
						+ iLaser * PixZoomSquare + ipix);
				*(Data + ilasertile * NThreads + ipix) = *(reorganized_data + ilasertile * PixZoomSquare
						+ ipix);
				i_data[ilasertile * PixZoomSquare + ipix] = 255.0
						* (*(reorganized_data + ilasertile * PixZoomSquare + ipix) - Minmicroimages)
						* ratioMI;
				Maxdata = max(Maxdata, i_data[ilasertile * PixZoomSquare + ipix]);
			}
		}
	verbosefile << " TILE ORG \u24FA Maxdata " << Maxdata << " Nbtile XY " << tile.NbTileXY << " NbTile XYD "
			<< tile.NbTileXYD << " Laserintile " << tile.maxLaserintile << endl;
	T4Dto2D(j_data, i_data, tile.NbTileXYD, tile.maxLaserintile, PixZoom, PixZoom);
	verbosefile << "HOST: \u24FB DEVICE TEST in biginspect.cu: Path to calculated new simulations "
			<< MIintilefile << " .....\n";
	sdkSavePGM(MIintilefile, i_data, PixZoom, tile.maxLaserintile * tile.NbTileXYD * PixZoom);
	sdkSavePGM(NIintilefile, j_data, tile.maxLaserintile * PixZoom, tile.NbTileXYD * PixZoom);

	return (micimintile);
}
