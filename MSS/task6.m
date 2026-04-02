%% Profiling the turbo coder system model
EbNo=1;
maxNumErrs=1e6;
maxNumBits=1e6;
profile on
ber=lab2_ex03_nIter(EbNo, maxNumErrs, maxNumBits , 1);
profile viewer