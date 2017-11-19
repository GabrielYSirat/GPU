/*
 * gpu_initialization.cu
 *
 *  Created on: Jun 23, 2017
 *      Author: gabriel
 */

#include"NewLoop.h"
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
    std::cout << endl << "******************Completion of GPU initialization ***************"<< endl;
    std::cout  << "******************************************************************"<< endl;
    std::cout << "used MB =  " << totalMB - freeMB << "   Free MB = " << freeMB << " Total MB = " << totalMB <<std::endl;
	printf("MAIN PROGRAM  \u2776 End of data preparation in device memory ...\n");
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
	  cout << "previous calculation: Number of Aggregates in x:" << NbAggregx  << " in y:" << NbAggregy;
	  cout << " Number of Tiles per aggregates in x:" << tileperaggregatex  << " in y:" << tileperaggregatey << endl;
	  cout << "Number of Tiles in x:" << NbTilex  << " in y:" << NbTiley <<endl ;
	  cout << "Max number of laser position in Tile:" << maxLaserintile  << " min value" << minLaserintile <<endl<<endl ;
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
		cout << "+++" << stepname[stepval]<< " Test validated++++ " << Stepdiag[stepval];
	else
		cout << "---" << stepname[stepval]<< " Test not validated++++  Sumdel =  " << Sumdel[stepval];
	if(stepval != 0) std::cout << std::fixed << " \u23F1 msec " <<" device  "  << Timestep[stepval]  << "  total " << Timetotal << endl;
	cout << "END STEP	*******end of step  " << stepval << "  " << stepname[stepval] << "**********************************" << endl << endl;
	stepval++;
	if(stepval != 9)
	cout << "STEP	*************  step " << stepval << "  " << stepname[stepval] << "*************" << endl;

}

int retrieveargv(string argvdata) {
	string name, value;
	stringstream ss(argvdata);
	getline(ss, name, '=');
	getline(ss, value);
	int result = atoi(value.c_str());
	return (result);
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
	if (stepval == 12) filebase.append("results/simusA1.pgm");

	if (stepval == 13) stepnumber.append("\u24F0");
	if (stepval == 13) dataliteral.append("RFactorA1");
	if (stepval == 13) callprogram.append("biginspect.cu");
	if (stepval == 13) filebase.append("results/RFactorA1.pgm");

	if (stepval == 7) stepnumber.append("\u24EF");
	if (stepval == 7) dataliteral.append("MicroimagesA1");
	if (stepval == 7) callprogram.append("tileorganization.cu");
	if (stepval == 7) filebase.append("results/microimagesB.pgm");

	unsigned char *i_data = (unsigned char *) calloc(n_colintern*n_rowintern, sizeof(unsigned char)); // on host

	for (int i = 0; i < tile.maxLaserintile * NThreads; i++)
		MaxData = max(MaxData, *(datavalues + i));
	printf("HOST: %s %d parameters %s in %s:  n_rowintern %d n_colintern %d, total %d MaxData %g\n",
			stepnumber.c_str(), stepval, dataliteral.c_str(), callprogram.c_str(),
			n_rowintern, n_colintern, tile.maxLaserintile * NThreads, MaxData);

	for (int idistrib = 0; idistrib < Ndistrib; idistrib++){

		const char * DataFile =  filebase.c_str ();
	for (int j_rowintern = 0; j_rowintern < n_rowintern; j_rowintern++)
		for (int i_colintern = 0; i_colintern < n_colintern; i_colintern++) {
			int i_microimage = i_colintern % PixZoom;
			int i_blocknumber =  (i_colintern % tile.NbTilex)/ PixZoom;
			int i_tile = i_colintern/(PixZoom * tile.blocks);
			int j_microimage = j_rowintern % PixZoom;
			int j_positioninblock = (j_rowintern % tile.NbTiley) / PixZoom;
			int j_tile = j_rowintern/(PixZoom *NIMAGESPARALLEL);

			int i = i_microimage + j_microimage * PixZoom +	// microimage
					(j_positioninblock + i_blocknumber * NIMAGESPARALLEL) * PixZoomSquare +
					(i_tile + j_tile * tile.NbTilex) * PixZoomSquare * tile.maxLaserintile ; // liste of microimages
			int tempi = 255.0 * datavalues[i] / MaxData;
			i_data[(i_microimage + i_blocknumber * PixZoom + i_tile * PixZoom * tile.blocks) + // x value
			        		(j_microimage + j_positioninblock * PixZoom + j_tile*PixZoom * NIMAGESPARALLEL)
			        					* PixZoom * tile.blocks] = tempi;// y value
		}
	printf("HOST: %s %d results %s in %s:: %s .....\n",
			 stepnumber.c_str(), stepval, dataliteral.c_str(), callprogram.c_str(),DataFile);
	sdkSavePGM(DataFile, i_data, n_colintern, n_rowintern);
	printf("HOST: %s %d ******************************************\n\n",
			 stepnumber.c_str(), stepval);
}
return (MaxData);
}
