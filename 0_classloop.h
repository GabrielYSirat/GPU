/*
 * 0_classloop.h
 *
 *  Created on: Jul 6, 2017
 *      Author: gabriel
 */

#ifndef CLASSLOOP_H_
#define CLASSLOOP_H_
#include "0_constants.h"
#include "0_constantsloop.h"

class COS {
public:
	float offsetLaserx, offsetLasery;
	float offsetROIx, offsetROIy;
	float offsetmicroimagesx, offsetmicroimagesy;
	float offsetPSFx, offsetPSFy;
	float offsetdistribx, offsetdistriby;
	float scaleLaserx, scaleLasery;
	float scaleROIx, scaleROIy;
	float scalemicroimagesx, scalemicroimagesy;
	float scalePSFx, scalePSFy;
	float scaledistribx, scaledistriby;
	void start(void);
};

class GPU_init {
public:
	int MP, MP_perdistrib;

	size_t sharedmemory;
	float Pixel_size_nm, XTileSize, YTileSize; // nm sizes

	/* pPSF */
	unsigned int Nb_Rows_PSF = 0;
	unsigned int Nb_Cols_PSF = 0;
	int PSF_size;

	/* Reconstruction */
	unsigned int Nb_Cols_reconstruction;
	unsigned int Nb_Rows_reconstruction;
	int reconstruction_size;

	/*Laser positions and MicroImages*/
	unsigned int Nb_Rows_microimages;
	unsigned int Nb_Cols_microimages;
	uint Nb_LaserPositions;

	int maxROIx, maxROIy, minROIx, minROIy;
	double maxLaserx, minLaserx, maxLasery, minLasery;
	int AmaxLaserx, AmaxLasery, AminLaserx, AminLasery;

	void start(void);
};

class Ctile {
public:

	int NbTile0x, NbTile0y;
	int NbTilex, NbTiley, NbTileXY, NbTileXYD;
	int tileperaggregatex, tileperaggregatey;
	int NbAggregx, NbAggregy;

	int Nblaserperdistribution[MAXNBDISTRIB] = { 0 }, maxlaserperdistribution = 0;
	int maxLaserintile = NIMAGESPARALLEL, minLaserintile =1.E6, blocks;
	uint NbLaserpertile[MAXTILE] = { 0 };
	int posintile[NUMLASERPOSITIONS];
	float Bconstant = 1.0;
	int startxdomain, startydomain;
	void print() const;
};

class devicedata {
public:
	int NbTilex, NbTiley, NbTileXY, NbTileXYD;
	int NbAggregx, NbAggregy;
	int tileperaggregatex, tileperaggregatey;
	int maxLaserintile, minLaserintile, blocks;
	uint Nb_LaserPositions;
	int imalimitpertile;
	uint NbLaserpertile[MAXTILE] = { 0 };
	float MaxPSF, MaxRec, Maxmicroimages, Maxdistrib ;
	float Bconstant;
	float MaxRfactor, MaxSimus;
	int step;
	int clockRate;
	int XTile, YTile;

};

#endif /* CLASSLOOP_H_ */
