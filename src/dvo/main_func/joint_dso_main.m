clc; clear; close all



%% load point cloud
freiburg2 = load('freiburg2.mat');
freiburg2 = freiburg2.freiburg2;

POSE = cell(length(freiburg2),1);
POSE{1} = eye(4);
COORD = cell(length(freiburg2),1);
COORD{1} = pose_to_coord(POSE{1});

for i = 1:length(freiburg2)-2
    
    tic
    
    % 1-2, 2-3, 1-3
    ptCloud1 = freiburg2{i};
    ptCloudMove = freiburg2{i+1};
    ptCloud3 = freiburg2{i+2};
    dvo = rgbd_dvo();
    R_init = eye(3);
    T_init = zeros(3,1);
    tform12 = affine3d([R_init, T_init; 0, 0, 0, 1]');
    tform23 = affine3d([R_init, T_init; 0, 0, 0, 1]');
    tform13 = affine3d([R_init, T_init; 0, 0, 0, 1]');
    %% downsample
    % downsample point clouds using grids
    
    percen_range = 0.04:0.02:0.08;
    if ~isempty(POSE{i+1})
        disp('already calculated')
        tform12.T = (POSE{i}\POSE{i+1})';
        fprintf('%d-%d Transformation Estimate:\n',i,i+1)
        disp(tform12.T')
    else
        for percen = percen_range
            fprintf('%d-%d\n',i,i+1)
            fprintf('%f resolution\n',percen)
            % moving - fixed : 1-2
            fixed1 = [];
            fixed1.ptcloud = removeInvalidPoints(pcdownsample(ptCloudMove, 'random', percen));
            fixed1.image = rgb2gray(ptCloudMove.Color);
            moving1 = removeInvalidPoints(pcdownsample(ptCloud1, 'random', percen));
            % make rkhs registration object
            dvo = rgbd_dvo();
            dvo.set_ptclouds(fixed1, moving1);
            dvo.tform = tform12;
            dvo.align();
            tform12 = dvo.tform;
            fprintf('%d-%d Transformation Estimate:\n',i,i+1)
            disp(tform12.T')
        end
    end

    for percen = percen_range
        fprintf('%d-%d\n',i+1,i+2)
        fprintf('%f resolution\n',percen)
        % moving - fixed : 2-3
        fixed2 = [];
        fixed2.ptcloud = removeInvalidPoints(pcdownsample(ptCloud3, 'random', percen));
        fixed2.image = rgb2gray(ptCloud3.Color);
        moving2 = removeInvalidPoints(pcdownsample(ptCloudMove, 'random', percen));
        % make rkhs registration object
        dvo = rgbd_dvo();
        dvo.set_ptclouds(fixed2, moving2);
        dvo.tform = tform23;
        dvo.align();
        tform23 = dvo.tform;
        fprintf('%d-%d Transformation Estimate:\n',i+1,i+2)
        disp(tform23.T')
    end

    for percen = percen_range
        fprintf('%d-%d\n',i,i+2)
        fprintf('%f resolution\n',percen)
        % moving - fixed : 1-3
        fixed3 = [];
        fixed3.ptcloud = removeInvalidPoints(pcdownsample(ptCloud3, 'random', percen));
        fixed3.image = rgb2gray(ptCloud3.Color);
        moving3 = removeInvalidPoints(pcdownsample(ptCloud1, 'random', percen));
        % make rkhs registration object
        dvo = rgbd_dvo();
        dvo.set_ptclouds(fixed3, moving3);
        dvo.tform.T = (tform12.T' * tform23.T')';
        dvo.align();
        tform13 = dvo.tform;
        fprintf('%d-%d Transformation Estimate:\n',i,i+2)
        disp(tform13.T')
    end


    % joint optimization 
    Z_pre = cell(1,3);
    Z_pre{1} = tform12.T';
    Z_pre{2} = tform23.T';
    Z_pre{3} = tform13.T';
    Keys = cell(1,3);
    Keys{1} = [1,2];
    Keys{2} = [2,3];
    Keys{3} = [1,3];
    % pose is not the same as twist!
    % pose{1} = eye, pose{2} = tf(1->2), pos{3} = tf(1->3)
    jointPose = joint_optimization(Z_pre, Keys);
    pose2 = jointPose{2};
    pose3 = jointPose{3};

    % update transformation
    tform12.T = pose2';
    tform23.T = (pose2\pose3)';
    tform13.T = pose3';
    fprintf('%d-%d Joint Optimization Transformation Estimate:\n',i,i+2)
%     disp(tform12.T')
%     disp(tform23.T')
%     disp(tform13.T')

    POSE{i} = POSE{i};
    POSE{i+1} = POSE{i}*pose2;
    POSE{i+2} = POSE{i}*pose3;
    
    % pose to coord
    COORD{i} = pose_to_coord(POSE{i});
    COORD{i+1} = pose_to_coord(POSE{i+1});
    COORD{i+2} = pose_to_coord(POSE{i+2});
    

    % transform 1 to 3
    ptCloudtransformed1 = pctransform(ptCloud1,tform13);

    mergeSize = 0.015;
    ptCloudScene = pcmerge(ptCloud3, ptCloudtransformed1, mergeSize);
    
    toc
    
%     % Visualize the input images.
%     figure(1)
%     subplot(2,2,1)
%     imshow(ptCloud3.Color)
%     title('First input image')
%     drawnow
% 
%     subplot(2,2,3)
%     imshow(ptCloud1.Color)
%     title('Second input image')
%     drawnow
% 
%     % Visualize the world scene.
%     subplot(2,2,[2,4])
%     pcshow(ptCloudScene, 'VerticalAxis','Y', 'VerticalAxisDir', 'Down')
%     title('Initial world scene')
%     xlabel('X (m)')
%     ylabel('Y (m)')
%     zlabel('Z (m)')
%     drawnow
    
    
end

%% trajectory
temp = 357;
X = zeros(temp,1);
Y = zeros(temp,1);
Z = zeros(temp,1);


for i = 1:temp
%     coor = pose_to_coord(POSEL{i})
%     X(i) = coor(1);
%     Y(i) = coor(2);
%     Z(i) = coor(3);
    X(i) = COORD{i}(1);
    Y(i) = COORD{i}(2);
    Z(i) = COORD{i}(3);
end


% 
% A = [X, Y, Z];
% GT = load('GT.mat');
% xyz = GT.xyz;
% xyz = xyz*10;
% 
% xyz(:,1) = xyz(:,1) - xyz(1,1);
% xyz(:,2) = xyz(:,2) - xyz(1,2);
% xyz(:,3) = xyz(:,3) - xyz(1,3);



figure(4)
plot3(X,Y,Z)
hold on
plot3(COORD_2(:,1),COORD_2(:,2),COORD_2(:,3))
hold off
legend('direct','indirect')



%% Stitch a Sequence of Point Clouds

PtCloud1 = freiburg2{1};
for i = 2:357
%     ptCloudCurrent = ptcloud_edge_filter(freiburg2{i});
    ptCloud2 = freiburg2{i};
    
    tform21 = affine3d(POSES_2{i}^(-1)'); % direct
%     tform21 = affine3d(poses{i}^(-1)'); % indirect
    
    ptCloudtransformed2 = pctransform(ptCloud2, tform21);

    mergeSize = 0.015;
    PtCloud1 = pcmerge(PtCloud1, ptCloudtransformed2, mergeSize);

end

% Visualize the world scene.
figure(5)
pcshow(PtCloud1, 'VerticalAxis','Y', 'VerticalAxisDir', 'Down')
title('world scene')
xlabel('X (m)')
ylabel('Y (m)')
zlabel('Z (m)')
drawnow