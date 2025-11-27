function traj_data = sim_shake(input_file, output_file, params)
% SIM_HANDHELD_SHAKE 模拟摄像机抖动效果
% 
% 输入:
%   input_file  - 输入视频路径
%   output_file - 输出视频路径
%   params      - (可选) 参数结构体，包含以下字段：
%       .max_shift_px  : 最大平移像素 (默认 15)
%       .max_angle_deg : 最大旋转角度 (默认 1.5)
%       .weight_jitter : 高频震颤权重 0~1 (默认 0.05)
%       .weight_drift  : 低频漂移权重 0~1 (默认 0.8)
%       .zoom_factor   : 缩放裁剪比例 (默认 1.15)
%
% 输出:
%   traj_data   - 包含生成的随机抖动轨迹的 table (Frame, ShiftX, ShiftY, RotationDeg)
%
% 示例:
%   p.max_shift_px = 20;
%   data = sim_handheld_shake('in.mp4', 'out.avi', p);

    %% 1. 参数校验与默认值设置
    if nargin < 3
        params = struct();
    end
    
    % 使用 isfield 检查参数，不存在则使用默认值
    if ~isfield(params, 'max_shift_px'), params.max_shift_px = 15; end
    if ~isfield(params, 'max_angle_deg'), params.max_angle_deg = 1.5; end
    if ~isfield(params, 'weight_jitter'), params.weight_jitter = 0.05; end
    if ~isfield(params, 'weight_drift'),  params.weight_drift = 0.8; end
    if ~isfield(params, 'zoom_factor'),   params.zoom_factor = 1.15; end

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

    fprintf('正在处理: %s -> %s\n', input_file, output_file);

    %% 3. 生成抖动轨迹
    % 生成高频噪声 (-1 ~ 1)
    noise_high_x = -1 + 2 * rand(numFrames, 1); 
    noise_high_y = -1 + 2 * rand(numFrames, 1);
    noise_high_r = -1 + 2 * rand(numFrames, 1);

    % 生成低频噪声 (平滑处理)
    smooth_window = round(frameRate * 0.5); 
    noise_low_x = smoothdata(randn(numFrames, 1), 'gaussian', smooth_window);
    noise_low_y = smoothdata(randn(numFrames, 1), 'gaussian', smooth_window);
    noise_low_r = smoothdata(randn(numFrames, 1), 'gaussian', smooth_window);

    % 归一化低频噪声辅助函数
    normalize = @(v) (v - min(v)) / (max(v) - min(v)) * 2 - 1;
    noise_low_x = normalize(noise_low_x);
    noise_low_y = normalize(noise_low_y);
    noise_low_r = normalize(noise_low_r);

    % 混合并应用幅度
    dx = (noise_high_x * params.weight_jitter + noise_low_x * params.weight_drift);
    dy = (noise_high_y * params.weight_jitter + noise_low_y * params.weight_drift);
    d_theta = (noise_high_r * params.weight_jitter + noise_low_r * params.weight_drift);

    % 最终映射
    dx = normalize(dx) * params.max_shift_px;
    dy = normalize(dy) * params.max_shift_px;
    d_theta = normalize(d_theta) * params.max_angle_deg;

    % 保存输出数据
    traj_data = table((1:numFrames)', dx, dy, d_theta, ...
        'VariableNames', {'Frame', 'ShiftX', 'ShiftY', 'RotationDeg'});

    %% 4. 逐帧处理循环
    % hWaitBar = waitbar(0, '初始化处理...');
    % cleanupObj = onCleanup(@() close(hWaitBar)); % 确保异常退出时关闭进度条

    % 预计算裁剪参数
    new_h = floor(h / params.zoom_factor);
    new_w = floor(w / params.zoom_factor);
    
    for k = 1:numFrames
        if hasFrame(vr)
            frame = readFrame(vr);
        else
            break;
        end

        % A. 放大
        frame_zoomed = imresize(frame, params.zoom_factor);
        
        % B. 仿射变换 (旋转 + 平移)
        theta = d_theta(k);
        tx = dx(k); 
        ty = dy(k);
        
        R = [cosd(theta)  sind(theta)  0;
            -sind(theta) cosd(theta)  0;
             0            0            1];
        T = [1  0  0;
             0  1  0;
             tx ty 1];
        
        tform = affine2d(R * T);
        frame_shaken = imwarp(frame_zoomed, tform, 'OutputView', imref2d(size(frame_zoomed)));

        % C. 中心裁剪
        [zh, zw, ~] = size(frame_shaken);
        crop_rect = [floor((zw-w)/2), floor((zh-h)/2), w-1, h-1];
        frame_final = imcrop(frame_shaken, crop_rect);
        
        % D. 尺寸兜底 (防止1像素误差)
        if size(frame_final, 1) ~= h || size(frame_final, 2) ~= w
            frame_final = imresize(frame_final, [h, w]);
        end
        
        writeVideo(vw, frame_final);

        % if mod(k, 10) == 0
        %     waitbar(k/numFrames, hWaitBar, sprintf('Processing Frame: %d/%d', k, numFrames));
        % end
    end
    
    close(vw);
    fprintf('处理完成: %s\n', output_file);
end