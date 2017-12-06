/*
 * gpu_initialization.cu
 *
 *  Created on: Jun 23, 2017
 *      Author: gabriel
 */

#include"0_Mainparameters.h"
string stepname[] = {"initialization  ", "PSF   ", "distrib  ",
		"Laser positions", "Measurement ROI  ", "microimages", " laser in tile ", "microimages in tile",  "reconstruction  ",
		"scratchpad    ", "bigLoop" , "end bigloop", "bigloop results"};
int smallnumber =20;
double Sumdel[16] = { 0 };
string Stepdiag[16] = NULL;

void report_gpu_mem()
{
    size_t free, total;
    float freeMB, totalMB;
    cudaMemGetInfo(&free, &total);
    freeMB =(float)free/(1024*1024);
    totalMB = (float)total/(1024*1024);
    verbosefile << endl << "******************Completion of GPU initialization ***************"<< endl;
    verbosefile  << "******************************************************************"<< endl;
    verbosefile << "used MB =  " << totalMB - freeMB << "   Free MB = " << freeMB << " Total MB = " << totalMB <<std::endl;
    verbosefile << "MAIN PROGRAM  \u2776 End of data preparation in device memory ...\n";
}


void GPU_init::start(void) {
/* pPSF */
	  PSF_Rows = pPSF*pZOOM;
	  Nb_Cols_PSF = pPSF*pZOOM;
	  PSF_size = (pPSF*pZOOM)*(pPSF*pZOOM);
	/* Reconstruction */
	  Nb_Cols_reconstruction = 0;
	  Nb_Rows_reconstruction = 0;

/*Laser positions and MicroImages*/
	  Nb_Rows_microimages = Npixel;
	  Nb_Cols_microimages = Npixel;

}

void COS::start(void) {
	offsetLaserx = 0.0;
	offsetLasery =0.0;
	offsetROIx = 0.0;
	offsetROIy = 0.0;
	offsetmicroimagesx = 0.0;
	offsetmicroimagesy = 0.0;
	offsetPSFx = 0.0;
	offsetPSFy = 0.0;
	offsetdistribx = 0.0;
	offsetdistriby =0.0;
	scaleLaserx = 1.0;
	scaleLasery =1.0;
	scaleROIx = 1.0;
	scaleROIy = 1.0;
	scalemicroimagesx = 1.0;
	scalemicroimagesy = 1.0;
	scalePSFx = 1.0;
	scalePSFy = 1.0;
	scaledistribx = 1.0;
	scaledistriby =1.0;
}

void Ctile::print() const
{
	  verbosefile << "previous calculation: Number of Aggregates in x:" << NbAggregx  << " in y:" << NbAggregy;
	  verbosefile << " Number of Tiles per aggregates in x:" << tileperaggregatex  << " in y:" << tileperaggregatey << endl;
	  verbosefile << "Number of Tiles in x:" << NbTilex  << " in y:" << NbTiley <<endl ;
	  verbosefile << "Max number of laser position in Tile:" << maxLaserintile  << " min value" << minLaserintile <<endl<<endl ;
}

void stepinit(int test, int& stepval)
{
Timestep[stepval] = ((float) (timer - time_start)) / clockRate;
	float Timetotal = ((float) (timer - time_init)) / clockRate;
	if(Sumdel[stepval] == 0)
		Stepdiag[stepval] = "PASS";
	else
		Stepdiag[stepval] = Sumdel[stepval];

	if (test)
		verbosefile << "+++" << stepname[stepval]<< " Test validated++++ " << Stepdiag[stepval];
	else
		verbosefile << "---" << stepname[stepval]<< " Test not validated++++  Sumdel =  " << Sumdel[stepval];
	if(stepval != 0) verbosefile << std::fixed << " \u23F1 msec " <<" device  "  << Timestep[stepval]  << "  total " << Timetotal << endl;
	verbosefile << "END STEP	*******end of step  " << stepval << "  " << stepname[stepval] << "**********************************" << endl << endl;
	stepval++;
	if(stepval != 9)
	verbosefile << "START STEP	*************  step " << stepval << "  " << stepname[stepval] << "*************" << endl;

}

int retrieveargv(string argvdata) {
	string name, value;
	stringstream ss(argvdata);
	getline(ss, name, '=');
	getline(ss, value);
	int result = atoi(value.c_str());
	return (result);
}

bool T4Dto2D(unsigned char *matrix4D, unsigned char *matrix2D, int dimension4, int dimension3,
		int dimension2, int dimension1) {
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
	printf("Max4D %d, max2D %d \n\n", max4D, max2D);
	return (TRUE);
}

float displaydata( float * datavalues, int stepval)
{
	float MaxData = 0.0f;
	int n_colintern = PixZoom * tile.blocks *tile.NbTilex;
	int n_rowintern = PixZoom * NIMAGESPARALLEL*tile.NbTiley;
	string stepnumber, dataliteral, callprogram,  filebase;

	if (stepval == 12) stepnumber.append("\u24EF");
	if (stepval == 12) dataliteral.append("SimusA1");
	if (stepval == 12) callprogram.append("biginspect.cu");
	if (stepval == 12) filebase.append("results/F_simusA1.pgm");

	if (stepval == 13) stepnumber.append("\u24F0");
	if (stepval == 13) dataliteral.append("RFactorA1");
	if (stepval == 13) callprogram.append("biginspect.cu");
	if (stepval == 13) filebase.append("results/G_RFactorA1.pgm");

	if (stepval == 7) stepnumber.append("\u24EF");
	if (stepval == 7) dataliteral.append("MicroimagesA1");
	if (stepval == 7) callprogram.append("tileorganization.cu");
	if (stepval == 7) filebase.append("results/C_microimagesdeviceloop.pgm");

	unsigned char *i_data = (unsigned char *) calloc(n_colintern*n_rowintern, sizeof(unsigned char)); // on host

	for (int i = 0; i < tile.maxLaserintile * NThreads; i++)
		MaxData = max(MaxData, *(datavalues + i));
	verbosefile << "HOST: " << stepnumber.c_str() << "  " <<  stepval << "parameters " << " n_rowintern " << n_rowintern;
	verbosefile << "n_colintern " << n_colintern << "MaxData " << MaxData;
	verbosefile << " dataliteral.c_str() " << dataliteral.c_str() << " callprogram.c_str() " << callprogram.c_str() << endl;

	for (int idistrib = 0; idistrib < Ndistrib; idistrib++){

		const char * DataFile = filebase.c_str ();

		for (int idistrib = 0, disdelta = 0; idistrib < Ndistrib; idistrib++, disdelta += tile.Nblaserperdistribution[idistrib])
			for (int iLaser = disdelta; iLaser < disdelta + tile.Nblaserperdistribution[idistrib]; iLaser++) {
				int tilex = pZOOM * (*(PosLaserx + iLaser) - tile.startx) / XTile;
				int tiley = pZOOM * (*(PosLasery + iLaser) - tile.starty) / YTile;
				int tilenumber = tilex + tile.NbTilex * tiley + tile.NbTilex * tile.NbTiley * idistrib;
				int ilasertile = tilenumber * tile.maxLaserintile + tile.posintile[iLaser];
				verbosefile << "TILE ORG \u247A idistrib " << idistrib << "  " << iLaser << " iLaser " << iLaser;
				verbosefile << " tilenumber " << tilenumber << " ilasertile " << ilasertile << endl;
				for (int ipix = 0; ipix < PixZoomSquare; ipix++) { // copy microimage to its position in the Data
					*(Data + ilasertile * PixZoomSquare + ipix) = *(zoomed_microimages + iLaser * PixZoomSquare + ipix);
					int xpix = ipix % PixZoom;	int ypix = ipix / PixZoom;
					i_data[tilenumber * PixZoom + tile.posintile[iLaser] * PixZoomSquare * tile.maxLaserintile + xpix + PixZoom * tile.maxLaserintile * ypix]
					       = 255.0 * (*(datavalues + ilasertile * PixZoomSquare + ipix) - Minmicroimages) /(Maxmicroimages - Minmicroimages);
			}
		}

		sdkSavePGM(DataFile, i_data,tile.maxLaserintile *PixZoom , tile.NbTileXYD * PixZoom);
	verbosefile << "HOST: " << stepnumber.c_str() << "  " <<  stepval << " ******************************************\n\n";
	}
	return (MaxData);
}

bool scratchdisplay (float * scratchdata, char * filename)
{
	unsigned char *i_scratchpad = (unsigned char *) calloc(tile.NbTileXY * XSCRATCH * YSCRATCH, sizeof(unsigned char)); // on host
	for (int iy = 0; iy < tile.NbTiley; iy++)
		for (int ix = 0; ix < tile.NbTilex; ix++)
			for (int iix = 0; iix < XTile; iix++)
				for (int iiy = 0; iiy < YTile; iiy++) {

					int iscratch = lostpixels + iix + dxSCRo2; 		// contribution of x in the 1D SCRATCH
					iscratch += ix * XSCRATCH; 					// contribution of previous tiles in x
					iscratch += (iiy + dySCRo2) * XSCRATCH * tile.NbTilex; 		// contribution of y in 1D SCRATCH
					iscratch += iy * YSCRATCH * XSCRATCH  * tile.NbTilex; 	// contribution of previous tiles in y

					int itile = iix;  // contribution of x in the TILE
					itile += ix * XTile; // contribution of previous tile in x
					itile += iiy * XTile * tile.NbTilex; // contribution of y in the TILE
					itile += iy * ATile * tile.NbTilex ; // contribution of previous tiles in y

					int iscratch2Dx = iix + dxSCRo2 + ix * XSCRATCH; 	// contribution of x in the 1D SCRATCH + contribution of previous tiles in x
					int iscratch2Dy = iiy + dySCRo2 + iy * YSCRATCH; 		// contribution of y in 1D SCRATCH +contribution of previous tiles in y
					int iscratch2D = iscratch2Dx + iscratch2Dy * XSCRATCH * tile.NbTilex;
					i_scratchpad[iscratch2D] = 255.0 * scratchdata[iscratch] / Maxscratch;
					if(!(i_scratchpad[iscratch2D] ==0) && VERBOSE){
					printf("SCRATCHPAD \u24FC itile %d, iscratch %d iscratch2Dx %d, iscratch2Dy %d iscratch2D %d\n",
							itile, iscratch, iscratch2Dx, iscratch2Dy, iscratch2D);
					printf("SCRATCHPAD \u24FC itile %d, i_scratchpad[iscratch2D] %d val_scratchpad[arg1D] %f\n",
							itile, i_scratchpad[iscratch2D], scratchdata[iscratch]);
					}
				}
return(TRUE);
}
