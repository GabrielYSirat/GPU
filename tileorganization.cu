/*
 * tileorganization.cu
 *
 *  Created on: Jul 3, 2017
 *      Author: gabriel
 */
#include "NewLoop.h"
#define TEST  1

__managed__ int *image_to_scratchpad_offset = { 0 }, *valid_image = { 0 };
__managed__ float *image_to_scratchpad_offset_global = { 0 };
__managed__ float *new_simus = { 0 }, *Data = { 0 }, *Rfactor = { 0 }, *distribvalidGPU = { 0 };

bool tileorganization(void) {
	bool Lasertile = TRUE;
	int organization_x[16] = { 0, 1, 2, 3, 2, 3, 3, 3, 4, 3, 3 };
	int organization_y[16] = { 0, 1, 1, 1, 2, 1, 2, 2, 2, 3, 3 };
	int tilex, tiley, tilenumber, posintile, ilasertile;

	cudaMallocManaged(&image_to_scratchpad_offset, MAXNUMBERLASERTILE * MAXTILE * sizeof(int));
	cudaMallocManaged(&valid_image, MAXNUMBERLASERTILE * MAXTILE * sizeof(int));

	// min and max Laser positions rounded to integer of camera pixels
	int AmaxLaserx = ceil(TA.maxLaserx);
	int AmaxLasery = ceil(TA.maxLasery);
	int AminLaserx = floor(TA.minLaserx);
	int AminLasery = floor(TA.minLasery);
	/************Tiles and aggregates*******************/
	printf(" ***********tiles and aggregates************** \n");
	filename = resourcesdirectory + "rec_image.xml";
	printf(" INIT PROG \u24FA tiles & aggregates:   \n");

	int temptile0x = TA.Nb_Cols_reconstruction / XTile;
	int temptile0y = TA.Nb_Rows_reconstruction / YTile;
	tile.NbTile0x = CEILING_POS((float )pZOOM*(AmaxLaserx - AminLaserx) / XTile);
	tile.NbTile0x = max(tile.NbTile0x, temptile0x);
	tile.NbTile0y = CEILING_POS((float )pZOOM*(AmaxLasery - AminLasery) / YTile);
	tile.NbTile0y = max(tile.NbTile0y, temptile0y);
	if(((AmaxLaserx - AminLaserx) > TA.Nb_Cols_reconstruction) ||
			((AmaxLasery - AminLasery) > TA.Nb_Rows_reconstruction))
		printf(" INIT PROG \u24FA \u26A0 tiles reconstruction too small!");

	printf(" INIT PROG \u24FA Min Number of tiles x:  %d y: %d\n ", tile.NbTile0x, tile.NbTile0y);

	/*************************Aggregates organization depending on MP*******/
	TA.MP_perdistrib = TA.MP / Ndistrib;
	printf("INIT PROG \u24FA Total number of MP per distribution %d  ", TA.MP_perdistrib);
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
	printf("INIT PROG \u24FA start x %d y %d MinLaser %d %d in REC pixels %d %d  \n",
			tile.startx, tile.starty, AminLaserx, AminLasery, tile.startx*pZOOM, tile.starty*pZOOM);


	TA.reconstruction_size = TA.Nb_Rows_reconstruction * TA.Nb_Cols_reconstruction;
	printf(" INIT PROG \u24FA Reconstruction size x: %d, y:%d \n", tile.reconstructionsizex, tile.reconstructionsizey);
	printf(" INIT PROG \u24FA Final number of tiles x: %d y: %d  \n\n", tile.NbTilex, tile.NbTiley);

	int disdelta = 0;
	for (int idistrib = 0; idistrib < Ndistrib; idistrib++) {
		for (int iLaser = disdelta; iLaser < disdelta + tile.Nblaserperdistribution[idistrib]; iLaser++) {
			// ATTENTION: REDEFINE BY THE TILE ORIGIN!!
			// position in tiles, tilex and tiley and overall tile number (including distrib)
			tilex = pZOOM * (*(PosLaserx + iLaser) - tile.startx) / XTile;
			tiley = pZOOM * (*(PosLasery + iLaser) - tile.starty) / YTile;
			tilenumber = tilex + tile.NbTilex * tiley + tile.NbTilex * tile.NbTiley * idistrib;
			float deltilex = *(PosLaserx + iLaser) * pZOOM - tilex * XTile;
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

			printf("TILE ORG \u24FA POS IN SCRATCH: numeral %d laser pos in x %f in y: %f  tile x: %d y: %d \n"
					"TILE ORG \u24FA POS IN SCRATCH: deltile x: %f and y %f del scratch x:%f y:%f\n"
					"TILE ORG \u24FA POS IN SCRATCH: ilasertile %d SCRATCH POSITION %d\n"
					"********************ilasertile %d offset scratchpad interaction****************** %d\n", iLaser,
					*(PosLaserx + iLaser), *(PosLasery + iLaser), tilex, tiley, deltilex, deltiley, delscratchx,
					delscratchy, ilasertile, image_to_scratchpad_offset[ilasertile], ilasertile,
					image_to_scratchpad_offset[ilasertile]);

			printf("TILE ORG \u24FA POS IN SCRATCH: image number %d tilenumber %d position in tile %d\n", iLaser,
					tilenumber, posintile);
		}
		disdelta += tile.Nblaserperdistribution[idistrib];

		printf("TILE ORG \u24FA idistrib %d  Nb laser per distribution %d\n", idistrib,
				tile.Nblaserperdistribution[idistrib]);
	}

	for (int it1 = 0; it1 < tile.NbTile; it1++) {
		printf("TILE ORG \u24FA Tile number %d tile in x %d tile in y %d distrib %d number of microimages %d\n", it1,
				it1 % (Ndistrib * tile.NbTiley), (it1 / tile.NbTilex) % Ndistrib, it1 / (tile.NbTilex * tile.NbTiley),
				tile.NbLaserpertile[it1]);

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

bool microimagesintile(void) {
float Maxdata = 0.0f;
int n_colintern = PixZoom * tile.blocks * tile.NbTilex;
int n_rowintern = PixZoom * NIMAGESPARALLEL * tile.NbTiley;
int tilex, tiley, tilenumber, ilasertile;
int AminLaserx = floor(TA.minLaserx);
int AminLasery = floor(TA.minLasery);

// Initialize new simus and Data
int tempa = tile.maxLaserintile * tile.NbTile * NThreads;
printf("TILE ORG \u2466 size simus %d \n", tempa);
cudaMallocManaged(&new_simus, tempa*sizeof(float));
cudaMallocManaged(&Data, tempa*sizeof(float));
cudaMallocManaged(&Rfactor, tempa*sizeof(float));
cudaMallocManaged(&distribvalidGPU, PSFZOOMSQUARE*sizeof(float));

for (int ii = 0; ii < tempa; ii++) {
	new_simus[ii] = 0.0f;
	Data[ii] = 0.0f;
	Rfactor[ii] = 0.0f;
}

printf("HOST: \u2466 DATA:  n_rowintern %d n_colintern %d, total %d Max data %g\n",
		n_rowintern, n_colintern, tile.maxLaserintile * NThreads, Maxdata);

int disdelta = 0;
for (int idistrib = 0; idistrib < Ndistrib; idistrib++) {
	for (int iLaser = disdelta; iLaser < disdelta + tile.Nblaserperdistribution[idistrib]; iLaser++) {
		tilex = pZOOM * (*(PosLaserx + iLaser) - AminLaserx) / XTile;
		tiley = pZOOM * (*(PosLasery + iLaser) - AminLasery) / YTile;
		tilenumber = tilex + tile.NbTilex * tiley + tile.NbTilex * tile.NbTiley * idistrib;
		ilasertile = tilenumber * MAXNUMBERLASERTILE + tile.NbLaserpertile[tilenumber];
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

