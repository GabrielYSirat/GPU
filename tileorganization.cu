/*
 * tileorganization.cu
 *
 *  Created on: Jul 3, 2017
 *      Author: gabriel
 */
#include "NewLoop.h"

__managed__ int *image_to_scratchpad_offset = { 0 }, *valid_image = { 0 };
__managed__ float *image_to_scratchpad_offset_global = { 0 };
int AmaxLaserx , AmaxLasery , AminLaserx, AminLasery;


bool tileorganization(void) {
	bool Lasertile = TRUE;
	int organization_x[16] = { 0, 1, 2, 3, 2, 2, 3, 3, 4, 3, 3 };
	int organization_y[16] = { 0, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3 };
	int tilex, tiley, tilenumber, posintile, ilasertile;

	filename = resourcesdirectory + "rec_image.xml";
	cudaMallocManaged(&image_to_scratchpad_offset, MAXNUMBERLASERTILE * MAXTILE * sizeof(int));
	cudaMallocManaged(&valid_image, MAXNUMBERLASERTILE * MAXTILE * sizeof(int));

	// min and max Laser positions rounded to integer of camera pixels
	AmaxLaserx = ceil(TA.maxLaserx); AmaxLasery = ceil(TA.maxLasery);
	AminLaserx = floor(TA.minLaserx); AminLasery = floor(TA.minLasery);

	/************Tiles and aggregates*******************/
	int recdeftile0x = ceil((float) TA.Nb_Cols_reconstruction / XTile);
	int recdeftile0y = ceil((float) TA.Nb_Rows_reconstruction / YTile);
	int laserdeftile0x = CEILING_POS((float )pZOOM*(AmaxLaserx - AminLaserx) / XTile);
	int laserdeftile0y = CEILING_POS((float )pZOOM*(AmaxLasery - AminLasery) / YTile);
	tile.NbTile0x = max(laserdeftile0x, recdeftile0x);
	tile.NbTile0y = max(laserdeftile0y, recdeftile0y);
	if(((AmaxLaserx - AminLaserx) > TA.Nb_Cols_reconstruction) || ((AmaxLasery - AminLasery) > TA.Nb_Rows_reconstruction))
		printf(" INIT PROG \u24FA \u26A0 tiles reconstruction too small!");

	printf(" INIT PROG \u24FA AmaxLaserx %d AmaxLasery %d AminLaserx %d AminLasery %d\n",
			AmaxLaserx, AmaxLasery, AminLaserx, AminLasery);
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
		tile.tileperaggregatey = organization_y[TA.MP_perdistrib]  ;
	}

	tile.NbTile = tile.NbTilex * tile.NbTiley * Ndistrib;
	/** FUTURE: In the real application the reconstruction
	 * is created by the program and not read from a file
	 * in this case the size data will be consistent by design
	 */
	// can be improved depending on the ratio between TILE0 and TILE: minor
	tile.reconstructionsizex = tile.NbTilex * XTile; // + (XSCRATCH - XTILE);
	TA.Nb_Cols_reconstruction = tile.reconstructionsizex;
	tile.reconstructionsizey = tile.NbTiley * YTile; //+ (YSCRATCH - YTILE);
	TA.Nb_Rows_reconstruction = tile.reconstructionsizey;
	tile.startx = AminLaserx; //floor(pZOOM*((AminLaserx + AmaxLaserx)/2 - (tile.NbTilex * XTile)/2));
	tile.starty = AminLasery ; //floor(pZOOM*((AminLasery + AmaxLasery)/2 - (tile.NbTiley * YTile)/2));
	TA.reconstruction_size = TA.Nb_Rows_reconstruction * TA.Nb_Cols_reconstruction;
	printf(" INIT PROG \u24FA Final number of tiles x: %d y: %d distrib %d  \n", tile.NbTilex, tile.NbTiley, Ndistrib);
	printf(" INIT PROG \u24FA Reconstruction size x: %d, y:%d \n", tile.reconstructionsizex, tile.reconstructionsizey);
	printf(" INIT PROG \u24FA NbTile %d start x %d y %d MinLaser %d %d in REC pixels %d %d  \n",
			tile.NbTile, tile.startx, tile.starty, AminLaserx, AminLasery, tile.startx*pZOOM, tile.starty*pZOOM);

	tile.NbLaserTotal = 0;
	for (int idistrib = 0; idistrib < Ndistrib; idistrib++) {
		for (int iLaser = tile.NbLaserTotal; iLaser < tile.NbLaserTotal + tile.Nblaserperdistribution[idistrib]; iLaser++) {
			// position in tiles, tilex and tiley and overall tile number (including distrib)
			tilex = pZOOM * (*(PosLaserx + iLaser) - tile.startx) / XTile;
			tiley = pZOOM * (*(PosLasery + iLaser) - tile.starty) / YTile;
			tilenumber = tilex + tile.NbTilex * tiley + tile.NbTilex * tile.NbTiley * idistrib;
			float deltilex = *(PosLaserx + iLaser) * pZOOM - tilex * XTile ;
			float deltiley = *(PosLasery + iLaser) * pZOOM - tiley * YTile;
			float delscratchx = deltilex + (XSCRATCH - XTile) / 2;  // XSCRATCH and XTile are odd
			float delscratchy = deltiley + (YSCRATCH - YTile) / 2;  // ySCRATCH and YTile are odd
			posintile = tile.NbLaserpertile[tilenumber]++;
			ilasertile = tilenumber * MAXNUMBERLASERTILE + posintile;
			valid_image[ilasertile] = 1;
			image_to_scratchpad_offset[ilasertile] = *(offsetFULL + iLaser);
			tile.maxLaserintile = max(tile.maxLaserintile, tile.NbLaserpertile[tilenumber]); // acquiring the max value per tile

			// where will be this microimage in the corresponding tile if posintile is 31, and tilenumber is 8?
			//  this microimage is the microimage with index 31 (the indexes begin at 0) of tile of index 8
			// add 1 - to go to 32 - to NbLaserpertile, because we added an image

			if (VERBOSE)
				printf(
						"TILE ORG \u24FA POS IN SCRATCH: numeral %d laser pos in x %f in y: %f  tile x: %d y: %d \n"
								"TILE ORG \u24FA POS IN SCRATCH: deltile x: %f and y %f del scratch x:%f y:%f\n"
								"TILE ORG \u24FA POS IN SCRATCH: ilasertile %d SCRATCH POSITION %d\n"
								"********************ilasertile %d offset scratchpad interaction****************** %d\n",
						iLaser, *(PosLaserx + iLaser), *(PosLasery + iLaser), tilex, tiley, deltilex,
						deltiley, delscratchx, delscratchy, ilasertile,
						image_to_scratchpad_offset[ilasertile], ilasertile,
						image_to_scratchpad_offset[ilasertile]);

			if (VERBOSE)
				printf("TILE ORG \u24FA POS IN SCRATCH: image number %d tilenumber %d position in tile %d\n",
						iLaser, tilenumber, posintile);
		}
		printf("TILE ORG \u24FA  idistrib n°%d number of laser positions in tile in distribution %d\n",
				idistrib, tile.Nblaserperdistribution[idistrib]);
		if (VERBOSE){
		int it0 = tile.NbTilex*tile.NbTiley*idistrib;
		for(int it=it0; it < it0 +tile.NbTilex*tile.NbTiley; it++)
			printf("tile %d: #lasers %d ...\n", it, tile.NbLaserpertile[it]);
		printf("\n");
		}
		tile.NbLaserTotal += tile.Nblaserperdistribution[idistrib];
	}
	printf("TILE ORG \u24FA  tile.NbLaserTotal %d \n",tile.NbLaserTotal);

	for (int it1 = 0; it1 < tile.NbTile; it1++) {
		if (VERBOSE)
			printf("TILE ORG \u24FA Tile number %d tile in x %d tile in y %d distrib %d number of microimages %d\n",
					it1, it1 % (Ndistrib * tile.NbTiley), (it1 / tile.NbTilex) % Ndistrib,
					it1 / (tile.NbTilex * tile.NbTiley), tile.NbLaserpertile[it1]);

		tile.maxLaserintile = max(tile.maxLaserintile, tile.NbLaserpertile[it1]);  // acquiring the max value per tile
		tile.minLaserintile = min(tile.minLaserintile, tile.NbLaserpertile[it1]);  // acquiring the min value per tile
	}

	printf("TILE ORG \u24FA Max  %d and Min %d  Laser in tile ...   \n", tile.maxLaserintile, tile.minLaserintile);
	tile.maxLaserintile = CEILING_POS(((float)tile.maxLaserintile)/NIMAGESPARALLEL) * NIMAGESPARALLEL;
	tile.blocks = tile.maxLaserintile / NIMAGESPARALLEL;
	// rounded to next multiple of NIMAGESPARALLEL
	printf("TILE ORG \u24FA Max Laser in tile rounded to next multiple of NIMAGESPARALLEL  .. %d\n",
			tile.maxLaserintile);

return (Lasertile);
}

bool initializesimusData(void) {
// Initialize new simus and Data
	int tempa = tile.maxLaserintile * tile.NbTile * NThreads;
	printf("TILE ORG \u2466 size simus %d AminLaserx %d AminLasery %d\n", tempa, AminLaserx, AminLasery);
	cudaMallocManaged(&new_simus, tempa * sizeof(float));
	cudaMallocManaged(&Data, tempa * sizeof(float));
	cudaMallocManaged(&Rfactor, tempa * sizeof(float));
	cudaMallocManaged(&distribvalidGPU, TA.MP * PSFZOOMSQUARE * sizeof(float));
	for (int itemp = 0; itemp < Ndistrib * PSFZOOMSQUARE; itemp++) *(distribvalidGPU + itemp) = 0.0;

	for (int ii = 0; ii < tempa; ii++) {
		new_simus[ii] = 0.0f;
		Data[ii] = 0.0f;
		Rfactor[ii] = 0.0f;
	}
	return(TRUE);
}

bool microimagesintile(void) {
	float Maxdata = 0.0f;
	int n_colintern = PixZoom * tile.blocks * tile.NbTilex;
	int n_rowintern = PixZoom * NIMAGESPARALLEL * tile.NbTiley;
	int tilex, tiley, tilenumber, ilasertile;

printf("HOST: \u2466 DATA:  n_rowintern %d n_colintern %d, total %d Max data %g\n",
		n_rowintern, n_colintern, tile.maxLaserintile * NThreads, Maxdata);

int disdelta = 0;
for (int idistrib = 0; idistrib < Ndistrib; idistrib++) {
	for (int iLaser = disdelta; iLaser < disdelta + tile.Nblaserperdistribution[idistrib]; iLaser++) {
		tilex = pZOOM * (*(PosLaserx + iLaser) - tile.startx) / XTile;
		tiley = pZOOM * (*(PosLasery + iLaser) - tile.starty) / YTile;
		tilenumber = tilex + tile.NbTilex * tiley + tile.NbTilex * tile.NbTiley * idistrib;
		ilasertile = tilenumber * tile.maxLaserintile + tile.NbLaserpertile[tilenumber];
		printf("temp idistrib %d, iLaser %d tilex %d tiley %d, tilenumber %d ilasertiel %d\n",
				idistrib, iLaser, tilex, tiley, tilenumber, ilasertile);
		for(int ipix = 0; ipix < PixZoomSquare; ipix++) // copy microimage to its position in the Data
			*(Data + ilasertile*PixZoomSquare + ipix) =  *(zoomed_microimages + iLaser* PixZoomSquare + ipix);
	}
	disdelta += tile.Nblaserperdistribution[idistrib];
	printf("TILE ORG \u24FA Max Laser in tile rounded to multiple NIMAGESPARALLEL  .. %d\n", tile.maxLaserintile);
}

const char * DataFile = "results/DataFile.pgm";
unsigned char *i_data = (unsigned char *) calloc(n_colintern * n_rowintern, sizeof(unsigned char)); // on host
for (int i = 0; i < tile.maxLaserintile * NThreads; i++) Maxdata = max(Maxdata, *(Data + i));
printf("HOST: \u277D DATA:  n_rowintern %d n_colintern %d, total %d Max data %g\n",
		n_rowintern, n_colintern, tile.maxLaserintile * NThreads, Maxdata);

bool micimintile = FALSE;
for (int idistrib = 0; idistrib < Ndistrib; idistrib++) {

	for (int j_rowintern = 0; j_rowintern < n_rowintern; j_rowintern++)
		for (int i_colintern = 0; i_colintern < n_colintern; i_colintern++) {
			int i_microimage = i_colintern % PixZoom;
			int i_blocknumber = (i_colintern % tile.NbTilex) / PixZoom;
			int i_tile = i_colintern / (PixZoom * tile.blocks);
			int j_microimage = j_rowintern % PixZoom;
			int j_positioninblock = (j_rowintern % tile.NbTiley) / PixZoom;
			int j_tile = j_rowintern / (PixZoom * NIMAGESPARALLEL);

			int i = i_microimage + j_microimage * PixZoom
					+ (j_positioninblock + i_blocknumber * NIMAGESPARALLEL) * PixZoomSquare // microimage
					+ (i_tile + j_tile * tile.NbTilex) * PixZoomSquare * tile.maxLaserintile; // list of microimages
			int tempi = 255.0 * Data[i] / Maxdata;
			i_data[(i_microimage + i_blocknumber * PixZoom + i_tile * PixZoom * tile.blocks) + 			// x value
					(j_microimage + j_positioninblock * PixZoom + j_tile * PixZoom * NIMAGESPARALLEL) 	// y value
					* PixZoom * tile.blocks] = tempi;
		}
	printf("HOST: \u277D DEVICE TEST in biginspect.cu: Path to calculated new simulations %s .....\n", DataFile);
	sdkSavePGM(DataFile, i_data, n_colintern, n_rowintern);
}
return (micimintile);
}

