function y = AWGNChannel(u, EbNo )
%% Initialization
persistent AWGN
if isempty(AWGN)
    AWGN             = comm.AWGNChannel;
end
AWGN.EbNo=EbNo;
y=AWGN.step(u);
end

