% test joint opt

Z = cell(3,1);
Z{1} = [0.9994    0.0126   -0.0309   -0.0381;
        -0.0125    0.9999    0.0039   -0.0019;
        0.0309   -0.0035    0.9995    0.0038;
        0         0         0    1.0000];
Z{2} = [0.9994    0.0082   -0.0326   -0.0484;
        -0.0083    1.0000   -0.0012    0.0001
        0.0326    0.0015    0.9995   -0.0010
        0         0         0    1.0000];
Z{3} = [0.9975    0.0201   -0.0681   -0.0822;
        -0.0201    0.9998    0.0017   -0.0030;
        0.0681   -0.0003    0.9977   -0.0003;
        0         0         0    1.0000];
    
Keys = cell(3,1);
Keys{1} = [1,2];
Keys{2} = [2,3];
Keys{3} = [1,3];

jointTwist = joint_optimization(Z, Keys);