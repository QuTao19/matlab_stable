%% 1. 加载图像与参数设置
clc; clear; close all;

% ================= 参数设置 (与 C++ 代码保持一致) =================
N = 8;              % 网格大小 (N x N)
sigma_diffuse = 0.8;% 扩散用的高斯 Sigma
kernel_size = 3;    % 扩散用的核大小

% 权重参数
w_mean = 0.3;       % 均值权重
w_std  = 0.7;       % 标准差权重
spatial_sigma_ratio = 0.6; % 空间高斯衰减系数 (相对于网格行数)
% ===============================================================

% --- 选择图像文件 ---
[file, path] = uigetfile({'*.jpg;*.png;*.bmp;*.tif', 'Image Files (*.jpg, *.png, *.bmp, *.tif)'}, '选择您的红外图像');
if isequal(file, 0)
    disp('用户取消了选择');
    return;
end
img_path = fullfile(path, file);
img_orig = imread(img_path);

% 转换为灰度图
if size(img_orig, 3) == 3
    img_gray = rgb2gray(img_orig);
else
    img_gray = img_orig;
end

img_double = double(img_gray);
[H, W] = size(img_double);

%% 2. 算法实现 (对应 C++ computeGridWeights)

cell_h = floor(H / N);
cell_w = floor(W / N);

% 图像中心 (网格坐标系)
center_x_grid = N / 2 + 0.5;
center_y_grid = N / 2 + 0.5;
spatial_sigma = N * spatial_sigma_ratio;

raw_weights = zeros(N, N);
debug_std = zeros(N, N);  % 用于调试显示标准差
debug_mean = zeros(N, N); % 用于调试显示均值

% --- 步骤 1: 计算每个网格的 (均值 + 标准差) * 空间权重 ---
for r = 1:N
    for c = 1:N
        % 定义 ROI
        x_start = (c-1) * cell_w + 1;
        y_start = (r-1) * cell_h + 1;
        x_end = min(x_start + cell_w - 1, W);
        y_end = min(y_start + cell_h - 1, H);
        
        roi = img_double(y_start:y_end, x_start:x_end);
        
        % 计算均值和标准差
        m = mean(roi(:));
        s = std(roi(:));
        
        debug_mean(r,c) = m;
        debug_std(r,c) = s;
        
        % A. 基础评分 (混合均值和标准差)
        % 对应 C++: float raw_score = m * 0.3f + s * 0.7f;
        base_score = m * w_mean + s * w_std;
        
        % B. 空间位置加权 (中心偏置)
        % 计算网格中心距离图像中心的距离 (网格坐标系)
        dist_sq = (c - center_x_grid)^2 + (r - center_y_grid)^2;
        
        % 高斯衰减
        spatial_weight = exp(-dist_sq / (2 * spatial_sigma^2));
        
        % 综合权重
        raw_weights(r, c) = base_score * spatial_weight;
    end
end

% --- 步骤 2: 第一次归一化 ---
max_val = max(raw_weights(:));
if max_val > 1e-5
    weights_norm1 = raw_weights / max_val;
else
    weights_norm1 = raw_weights;
end

% --- 步骤 3: 权重扩散 (高斯模糊) ---
h_gauss = fspecial('gaussian', [kernel_size kernel_size], sigma_diffuse);
diffused_weights = imfilter(weights_norm1, h_gauss, 'replicate');

% --- 步骤 4: 第二次归一化 ---
max_val_diff = max(diffused_weights(:));
if max_val_diff > 1e-5
    final_weights = diffused_weights / max_val_diff;
else
    final_weights = diffused_weights;
end

%% 3. 2D 可视化

figure('Name', '2D Analysis: Mean vs Std vs Final', 'Color', 'w', 'Position', [100, 100, 1200, 400]);

% 子图1: 原始图像
subplot(1, 2, 1);
imshow(img_gray); 
% title('原始红外图像');
hold on;
% 绘制网格
for i = 1:N-1
    line([1, W], [i*cell_h, i*cell_h], 'Color', '#94C6CD', 'LineWidth', 1);
    line([i*cell_w, i*cell_w], [1, H], 'Color', '#94C6CD', 'LineWidth', 1);
end

% 子图3: 最终权重 (叠加)
subplot(1, 2, 2);
imshow(img_gray); hold on;
% 放大权重图以覆盖原图
weight_overlay = imresize(final_weights, [H, W], 'nearest');
h = imshow(weight_overlay);
set(h, 'AlphaData', 0.6);
colormap(gca, 'jet'); colorbar;
% title('最终计算权重 (Score + CenterBias)');

% 显示数值
for r = 1:N
    for c = 1:N
        cx = (c-1)*cell_w + cell_w/2;
        cy = (r-1)*cell_h + cell_h/2;
        % 只显示较大的权重值，避免杂乱
        if final_weights(r,c) > 0.1
            text(cx, cy, sprintf('%.2f', final_weights(r,c)), ...
                'Color', 'w', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
        end
    end
end

% % 子图3: 中间特征 (标准差分布)
% subplot(1, 3, 3);
% imagesc(debug_std); axis image; colormap(gca, 'parula'); colorbar;
% title('中间特征: 区域标准差 (Std Dev)');
% xlabel('高标准差通常对应复杂纹理/目标');