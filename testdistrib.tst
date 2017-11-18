	for (int idistrub = ithreads; idistrub < ADistrib; idistrub += THREADSVAL)
			*(test2_distrib + idistrub + itc * ADistrib) = *(shared_distrib + idistrub);