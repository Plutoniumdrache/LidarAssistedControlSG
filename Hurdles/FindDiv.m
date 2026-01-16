
N = 66000;
dt = 0.01;
Res = [];
for i = 1:2*N*dt
    k = i/dt;
    if ~mod(N,k)
        Res = [Res, i];
    end
end
Res