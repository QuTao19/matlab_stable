function traj_data = sim_shake(input_file, output_file, params)
% SIM_SHAKE 模拟不同类型的摄像机抖动
% 
% 修正版说明: 修复了 persistent 变量导致的 "当前工作区中存在变量" 错误

    %% 1. 参数校验与默认值设置
    if nargin < 3
        params = struct();
    end
    
    if ~isfield(params, 'max_shift_px'), params.max_shift_px = 15; end
    if ~isfield(params, 'max_angle_deg'), params.max_angle_deg = 1.5; end
    if ~isfield(params, 'weight_jitter'), params.weight_jitter = 0.05; end
    if ~isfield(params, 'weight_drift'),  params.weight_drift = 0.8; end
    if ~isfield(params, 'zoom_factor'),   params.zoom_factor = 1.15; end
    if ~isfield(params, 'smooth_sec'),    params.smooth_sec = 0.5; end

    if ~isfile(input_file)
        error('找不到输入文件: %s', input_file);
    end

    %% 2. 初始化视频读写
    vr = VideoReader(input_file);
    frameRate = vr.FrameRate;
    numFrames = vr.NumFrames;
    h = vr.Height;
    w = vr.Width;

    vw = VideoWriter(output_file, 'Motion JPEG AVI');
    vw.FrameRate = frameRate;
    open(vw);

    %% 3. 生成抖动轨迹
    % 生成高频噪声 (-1 ~ 1)
    noise_high_x = -1 + 2 * rand(numFrames, 1); 
    noise_high_y = -1 + 2 * rand(numFrames, 1);
    noise_high_r = -1 + 2 * rand(numFrames, 1);

    % 生成低频噪声 (平滑处理)
    smooth_window = max(3, round(frameRate * params.smooth_sec)); 
    
    noise_low_x = smoothdata(randn(numFrames, 1), 'gaussian', smooth_window);
    noise_low_y = smoothdata(randn(numFrames, 1), 'gaussian', smooth_window);
    noise_low_r = smoothdata(randn(numFrames, 1), 'gaussian', smooth_window);

    % 归一化
    normalize = @(v) (v - min(v)) / (max(v) - min(v)) * 2 - 1;
    
    if range(noise_low_x) > 0, noise_low_x = normalize(noise_low_x); end
    if range(noise_low_y) > 0, noise_low_y = normalize(noise_low_y); end
    if range(noise_low_r) > 0, noise_low_r = normalize(noise_low_r); end

    % 混合
    dx = (noise_high_x * params.weight_jitter + noise_low_x * params.weight_drift);
    dy = (noise_high_y * params.weight_jitter + noise_low_y * params.weight_drift);
    d_theta = (noise_high_r * params.weight_jitter + noise_low_r * params.weight_drift);

    % 最终映射
    if range(dx) > 0, dx = normalize(dx) * params.max_shift_px; end
    if range(dy) > 0, dy = normalize(dy) * params.max_shift_px; end
    if range(d_theta) > 0, d_theta = normalize(d_theta) * params.max_angle_deg; end

    % 保存输出数据
    traj_data = table((1:numFrames)', dx, dy, d_theta, ...
        'VariableNames', {'Frame', 'ShiftX', 'ShiftY', 'RotationDeg'});

    %% 4. 逐帧处理循环
    % 预计算裁剪参数
    new_h = floor(h / params.zoom_factor);
    new_w = floor(w / params.zoom_factor);
    
    % 初始化帧计数器 (普通的局部变量)
    frame_idx = 0;

    while hasFrame(vr)
        frame = readFrame(vr);
        frame_idx = frame_idx + 1; % 计数器自增
        
        % A. 放大
        frame_zoomed = imresize(frame, params.zoom_factor);
        
        % B. 仿射变换
        if frame_idx <= height(traj_data)
            theta = d_theta(frame_idx);
            tx = dx(frame_idx); 
            ty = dy(frame_idx);
        else
            % 如果读出的帧数超过了预计帧数，使用0偏移
            theta = 0; tx = 0; ty = 0;
        end
        
        R = [cosd(theta)  sind(theta)  0;
            -sind(theta) cosd(theta)  0;
             0            0            1];
        T = [1  0  0;
             0  1  0;
             tx ty 1];
        
        tform = affine2d(R * T);
        
        % 黑色填充边缘
        frame_shaken = imwarp(frame_zoomed, tform, 'OutputView', imref2d(size(frame_zoomed)), 'FillValues', 0);

        % C. 中心裁剪
        [zh, zw, ~] = size(frame_shaken);
        center_rect = [floor((zw-w)/2) + 1, floor((zh-h)/2) + 1, w-1, h-1];
        
        frame_final = imcrop(frame_shaken, center_rect);
        
        % D. 尺寸兜底
        if size(frame_final, 1) ~= h || size(frame_final, 2) ~= w
            frame_final = imresize(frame_final, [h, w]);
        end
        
        writeVideo(vw, frame_final);
    end
    
    close(vw);
end