/*
 * gpu_initialization.cu
 *
 *  Created on: Jun 23, 2017
 *      Author: gabriel
 */

#include"0_Mainparameters.h"

double Timestep[16];
string stepname[] = { "initialization  ", "PSF  ", " distrib  ", " Laser positions", " Measurement ROI  ",
		" microimages  ", " laser in tile  ", " microimages in tile  ", " reconstruction  ", " scratchpad    ",
		" bigLoop  ", " end bigloop  ", " bigloop results  "};
double Sumdel[16] = { 0 };
string Stepdiag[16] = NULL;

void report_gpu_mem() {
	size_t free, total;
	float freeMB, totalMB;
	cudaMemGetInfo(&free, &total);
	freeMB = (float) free / (1024 * 1024);
	totalMB = (float) total / (1024 * 1024);
	verbosefile << endl << "******************Completion of GPU initialization ***************" << endl;
	verbosefile << "******************************************************************" << endl;
	verbosefile << "used MB =  " << totalMB - freeMB << "   Free MB = " << freeMB << " Total MB = " << totalMB
			<< std::endl;
	verbosefile << "MAIN PROGRAM  \u2776 End of data preparation in device memory ...\n";
}

void GPU_init::start(void) {
	/* pPSF */
	Nb_Rows_PSF = pPSF * pZOOM;
	Nb_Cols_PSF = pPSF * pZOOM;
	PSF_size = (pPSF * pZOOM) * (pPSF * pZOOM);
	/* Reconstruction */
	Nb_Cols_reconstruction = 0;
	Nb_Rows_reconstruction = 0;

	/*Laser positions and MicroImages*/
	Nb_Rows_microimages = Npixel;
	Nb_Cols_microimages = Npixel;
	maxLaserx = 0.0;
	maxLasery = 0.0;
	minLaserx = 1.E6;
	minLasery = 1.E6;

}

void COS::start(void) {
	offsetLaserx = 0.0;
	offsetLasery = 0.0;
	offsetROIx = 0.0;
	offsetROIy = 0.0;
	offsetmicroimagesx = 0.0;
	offsetmicroimagesy = 0.0;
	offsetPSFx = 0.0;
	offsetPSFy = 0.0;
	offsetdistribx = 0.0;
	offsetdistriby = 0.0;
	scaleLaserx = 1.0;
	scaleLasery = 1.0;
	scaleROIx = 1.0;
	scaleROIy = 1.0;
	scalemicroimagesx = 1.0;
	scalemicroimagesy = 1.0;
	scalePSFx = 1.0;
	scalePSFy = 1.0;
	scaledistribx = 1.0;
	scaledistriby = 1.0;
}

void Ctile::print() const {
	verbosefile << "previous calculation: Number of Aggregates in x:" << NbAggregx << " in y:" << NbAggregy;
	verbosefile << " Number of Tiles per aggregates in x:" << tileperaggregatex << " in y:"
			<< tileperaggregatey << endl;
	verbosefile << "Number of Tiles in x:" << NbTilex << " in y:" << NbTiley << endl;
	verbosefile << "Max number of laser position in Tile:" << maxLaserintile << " min value" << minLaserintile
			<< endl << endl;
}

void stepinit(int test, int& stepval) {
	Timestep[stepval] = ((float) (timer - time_start)) / clockRate;
	float Timetotal = ((float) (timer - time_init)) / clockRate;
	if (Sumdel[stepval] == 0)
		Stepdiag[stepval] = "PASS";
	else
		Stepdiag[stepval] = Sumdel[stepval];

	if (test)
		verbosefile << "+++" << stepname[stepval] << " Test validated++++ " << Stepdiag[stepval];
	else
		verbosefile << "---" << stepname[stepval] << " Test not validated++++  Sumdel =  " << Sumdel[stepval];
	if (stepval != 0)
		verbosefile << std::fixed << " \u23F1 msec " << " device  " << Timestep[stepval] << "  total "
				<< Timetotal << endl;
	verbosefile << "END STEP	*******end of step  " << stepval << "  " << stepname[stepval]
			<< "**********************************" << endl << endl;
	stepval++;
		verbosefile << "START STEP	*************  step " << stepval << "  " << stepname[stepval]
				<< "*************" << endl;

}

int retrieveargv(string argvdata) {
	string name, value;
	stringstream ss(argvdata);
	getline(ss, name, '=');
	getline(ss, value);
	int result = atoi(value.c_str());
	return (result);
}

bool T4Dto2D(unsigned char *matrix4D, unsigned char *matrix2D, int dimension4, int dimension3, int dimension2,
		int dimension1) {
	int max4D = 0, max2D = 0;
	for (int i1 = 0; i1 < dimension1; i1++)
		for (int i2 = 0; i2 < dimension2; i2++)
			for (int i3 = 0; i3 < dimension3; i3++)
				for (int i4 = 0; i4 < dimension4; i4++) {
					int xvalue = (i4 * dimension1 + i1);
					int yvalue = (i3 * dimension2 + i2);
					*(matrix4D + xvalue + yvalue * dimension1 * dimension3) = *(matrix2D
							+ i4 * dimension3 * dimension2 * dimension1 + i3 * dimension2 * dimension1
							+ i2 * dimension1 + i1);
				}
	for (int i1 = 0; i1 < dimension4 * dimension3 * dimension2 * dimension1; i1++) {
		max4D = max(max4D, *(matrix4D + i1));
		max2D = max(max2D, *(matrix2D + i1));

	}
	return (TRUE);
}

float displaydata(float * datavalues, int stepval) {
	float MaxData = 0.0f;
	int n_colintern = PixZoom * tile.blocks * tile.NbTilex;
	int n_rowintern = PixZoom * NIMAGESPARALLEL * tile.NbTiley;
	string stepnumber, dataliteral, callprogram, filebase;

	if (stepval == 12)
		stepnumber.append("\u24EF");
	if (stepval == 12)
		dataliteral.append("SimusA1");
	if (stepval == 12)
		callprogram.append("biginspect.cu");
	if (stepval == 12)
		filebase.append("results/F_simusA1.pgm");

	if (stepval == 13)
		stepnumber.append("\u24F0");
	if (stepval == 13)
		dataliteral.append("RFactorA1");
	if (stepval == 13)
		callprogram.append("biginspect.cu");
	if (stepval == 13)
		filebase.append("results/G_RFactorA1.pgm");

	if (stepval == 7)
		stepnumber.append("\u24FB");
	if (stepval == 7)
		dataliteral.append("MicroimagesA1");
	if (stepval == 7)
		callprogram.append("tileorganization.cu");
	if (stepval == 7)
		filebase.append("results/C_microimagesdeviceloop.pgm");

	unsigned char *i_data = (unsigned char *) calloc(n_colintern * n_rowintern, sizeof(unsigned char)); // on host

	for (int i = 0; i < tile.maxLaserintile * NThreads; i++)
		MaxData = max(MaxData, *(datavalues + i));
	verbosefile << "HOST: " << stepnumber.c_str() << "  " << stepval << "parameters " << " n_rowintern "
			<< n_rowintern;
	verbosefile << "n_colintern " << n_colintern << "MaxData " << MaxData;
	verbosefile << " dataliteral.c_str() " << dataliteral.c_str() << " callprogram.c_str() "
			<< callprogram.c_str() << endl;

	for (int idistrib = 0; idistrib < Ndistrib; idistrib++) {

		const char * DataFile = filebase.c_str();

		for (int idistrib = 0, disdelta = 0; idistrib < Ndistrib;
				idistrib++, disdelta += tile.Nblaserperdistribution[idistrib])
			for (int iLaser = disdelta; iLaser < disdelta + tile.Nblaserperdistribution[idistrib]; iLaser++) {
				int tilex = pZOOM * (*(PosLaserx + iLaser) - tile.startxdomain) / XTile;
				int tiley = pZOOM * (*(PosLasery + iLaser) - tile.startydomain) / YTile;
				int tilenumber = tilex + tile.NbTilex * tiley + tile.NbTilex * tile.NbTiley * idistrib;
				int ilasertile = tilenumber * tile.maxLaserintile + tile.posintile[iLaser];
				verbosefile << "TILE ORG \u24FA idistrib " << idistrib << "  " << iLaser << " iLaser "
						<< iLaser;
				verbosefile << " tilenumber " << tilenumber << " ilasertile " << ilasertile << endl;
				for (int ipix = 0; ipix < PixZoomSquare; ipix++) { // copy microimage to its position in the Data
					*(Data + ilasertile * PixZoomSquare + ipix) = *(zoomed_microimages
							+ iLaser * PixZoomSquare + ipix);
					int xpix = ipix % PixZoom;
					int ypix = ipix / PixZoom;
					i_data[tilenumber * PixZoom + tile.posintile[iLaser] * PixZoomSquare * tile.maxLaserintile
							+ xpix + PixZoom * tile.maxLaserintile * ypix] = 255.0
							* (*(datavalues + ilasertile * PixZoomSquare + ipix) - Minmicroimages)
							/ (Maxmicroimages - Minmicroimages);
				}
			}

		sdkSavePGM(DataFile, i_data, tile.maxLaserintile * PixZoom, tile.NbTileXYD * PixZoom);
		verbosefile << "HOST: " << stepnumber.c_str() << "  " << stepval
				<< " ******************************************\n\n";
	}
	return (MaxData);
}
int sizesimus = tile.maxLaserintile * tile.NbTileXY * NThreads;

float displaySimus(float * simusvalues) {
/*	float MaxSimusD = 0.0f, MinSimusD = 1.E6;
	unsigned char *i_simus = (unsigned char *) calloc(sizesimus, sizeof(unsigned char)); // on host
	string filebase, file;
	int n_colintern = PixZoom * tile.NbTileXY;
	int n_rowintern = PixZoom * tile.maxLaserintile;

	filebase.append("results/F_simus");

	for (int i = 0; i < datafullsize; i++) MaxSimusD = max(MaxSimusD, *(simusvalues + i)); // all distributions!!
	for (int i = 0; i < datafullsize; i++) MinSimusD = min(MinSimusD, *(simusvalues + i));
	float ratio = 255. / (MaxSimusD - MinSimusD);*/

/*	verbosefile << "HOST: \u24EF parameters: n_rowintern " << n_rowintern << "n_colintern " << n_colintern
			<< "MaxSimusD " << MaxSimusD << " MinSimusD " << MinSimusD << " Simulations call program biginspect.cu " << endl;

/*	for (int idistrib = 0; idistrib < Ndistrib; idistrib++) {
		file = filebase + to_string(idistrib) + ".pgm";
		verbosefile << "file " << file << endl;

		for (int isimus = 0; isimus < sizesimus; isimus++) {
			int imicro = isimus / NThreads; // number of microimage
			int ipixel = isimus % NThreads; // pixel number in microimage
			if (ipixel < PixZoomSquare) {
				int ix = ipixel % PixZoom + PixZoom * imicro % tile.maxLaserintile;
				int iy = ipixel / PixZoom + imicro/tile.maxLaserintile *PixZoomSquare;
				i_simus[isimus] = ratio * (simusvalues[ix + iy * PixZoom] - MinSimusD);
			}
		}
		sdkSavePGM(file.c_str(), i_simus, PixZoom, PixZoom*fullnumberoflasers);
	}*/

	return (TRUE);
}

float scratchreaddisplay(float * reconstructiondata, float * scratchdata, const char * filename, bool readtile) {
	unsigned char *i_scratchpad = (unsigned char *) calloc(tile.NbTileXY * XSCRATCH * YSCRATCH, sizeof(unsigned char));
	float MaxScratchlocal = 0.0f;
	for (int iy = 0; iy < tile.NbTiley; iy++)
		for (int ix = 0; ix < tile.NbTilex; ix++)
			for (int iix = 0; iix < XTile; iix++)
				for (int iiy = 0; iiy < YTile; iiy++) {

					int iscratch = lostpixels + iix + dxSCRo2; 		// contribution of x in the 1D SCRATCH
					iscratch += ix * XSCRATCH; 					// contribution of previous tiles in x
					iscratch += (iiy + dySCRo2) * XSCRATCH * tile.NbTilex; 	// contribution of y in 1D SCRATCH
					iscratch += iy * ASCRATCH * tile.NbTilex; // contribution of previous tiles in y

					int itile = iix;  // contribution of x in the TILE
					itile += ix * XTile; // contribution of previous tile in x
					itile += iiy * XTile * tile.NbTilex; // contribution of y in the TILE
					itile += iy * ATile * tile.NbTilex; // contribution of previous tiles in y

					int iscratch2Dx = iix + dxSCRo2 + ix * XSCRATCH; // contribution of x in the 1D SCRATCH + contribution of previous tiles in x
					int iscratch2Dy = iiy + dySCRo2 + iy * YSCRATCH; // contribution of y in 1D SCRATCH +contribution of previous tiles in y
					int iscratch2D = iscratch2Dx + iscratch2Dy * XSCRATCH * tile.NbTilex;
					if (readtile)
						scratchdata[iscratch] = reconstructiondata[itile];
					MaxScratchlocal = max(MaxScratchlocal, scratchdata[iscratch]);
					i_scratchpad[iscratch2D] = 255.0 * scratchdata[iscratch] / Maxscratch;
					if (!(i_scratchpad[iscratch2D] == 0) && NOVERBOSE) {
						printf(
								"SCRATCHPAD \u24FC itile %d, iscratch %d iscratch2Dx %d, iscratch2Dy %d iscratch2D %d\n",
								itile, iscratch, iscratch2Dx, iscratch2Dy, iscratch2D);
						printf(
								"SCRATCHPAD \u24FC itile %d, i_scratchpad[iscratch2D] %d val_scratchpad[arg1D] %f\n",
								itile, i_scratchpad[iscratch2D], scratchdata[iscratch]);

					}
				}
	sdkSavePGM(filename, i_scratchpad, XSCRATCH * tile.NbTilex, YSCRATCH * tile.NbTiley);
	return (MaxScratchlocal);
}

float scratch2D2tile(float * fscratch2D, float * ftile, int fxtile, int fytile, int fXscratch, int fYscratch)
{
	float maxtile = 0.0f;

	int del = fXscratch - fxtile + (fYscratch - fytile)*fXscratch;

	for (int itile=0; itile < fxtile*fytile; itile++) {
			ftile[itile] = fscratch2D[itile+del];
			maxtile = max(maxtile, fscratch2D[itile+del]);
		}

	return maxtile;
}

float tile2scratch2D(float * fscratch2D, float * ftile, int fxtile, int fytile, int fXscratch, int fYscratch)
{
	float maxscratch = 0.0f;

	for(int iscratch=0; iscratch < fXscratch*fYscratch; iscratch++)
		fscratch2D[iscratch]=0.0f;

	int del = fXscratch - fxtile + (fYscratch - fytile)*fXscratch;

	for (int itile=0; itile < fxtile*fytile; itile++) {
		fscratch2D[itile+del] = ftile[itile];
		maxscratch = max(maxscratch, fscratch2D[itile+del]);
		}

	return maxscratch;
}

float scratch2D2scratch1D(float * fscratch2D, float * fscratch1D, int fXscratch, int fYscratch, int fAscratch, int flostpixels)
{
	float maxscratch1D = 0.0f;
/* first lost pixels to zero
 *
 */
	for (int iscratch = 0; iscratch < flostpixels; iscratch++) fscratch1D[iscratch] = 0.0f;
/* fXscratch * fYscratch real pixels
 *
 */
	for (int iscratch2D=0; iscratch2D < fXscratch*fYscratch; iscratch2D++) {
			fscratch1D[flostpixels+iscratch2D] = fscratch2D[iscratch2D];
			maxscratch1D = max(maxscratch1D, fscratch2D[iscratch2D]);
		}
	/* last pixels
	 *
	 */
	for (int iscratch = fXscratch*fYscratch+flostpixels; iscratch < fAscratch; iscratch++)
		fscratch1D[iscratch] = 0.0f;

	return maxscratch1D;
}

float scratch1D2scratch2D(float * fscratch2D, float * fscratch1D, const char * filename, int fXscratch,
		int fYscratch, int flostpixels) {
	float maxscratch2D = 0.0f;
	unsigned char *i_scratch2D = (unsigned char *) calloc(fXscratch * fYscratch, sizeof(unsigned char));
	/* fXscratch * fYscratch real pixels
	 *
	 */
	for (int iscratch2D = 0; iscratch2D < fXscratch * fYscratch; iscratch2D++) {
		fscratch2D[iscratch2D] = fscratch1D[flostpixels + iscratch2D];
		maxscratch2D = max(maxscratch2D, *(fscratch2D + iscratch2D));
	}
	float ratio = 255. / maxscratch2D;

	for (int iscratch2D = 0; iscratch2D < fXscratch * fYscratch; iscratch2D++)
		i_scratch2D[iscratch2D] = ratio * fscratch2D[iscratch2D];

	if (filename != NULL)
		sdkSavePGM(filename, i_scratch2D, fXscratch, fYscratch);
	return maxscratch2D;
}
