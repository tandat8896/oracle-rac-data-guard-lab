# 3Sum - LeetCode 15

## Đề bài

Cho mảng số nguyên `nums`, trả về tất cả các bộ 3 `[nums[i], nums[j], nums[k]]` sao cho:
- `i != j`, `i != k`, `j != k` (3 chỉ số khác nhau)
- `nums[i] + nums[j] + nums[k] == 0`
- **Không trùng lặp** bộ 3 (distinct triplets)

### Ví dụ 1

```
Input: nums = [-1,0,1,2,-1,-4]
Output: [[-1,-1,2],[-1,0,1]]
```

Giải thích:
- (-1) + 0 + 1 = 0
- (-1) + 2 + (-1) = 0
- Chỉ có 2 bộ distinct

### Ví dụ 2

```
Input: nums = [0,1,1]
Output: []
```

### Ví dụ 3

```
Input: nums = [0,0,0]
Output: [[0,0,0]]
```

---

## Thuật toán: Sort + Two Pointers

### Ý tưởng

1. **Sort mảng** - O(n log n)
   - Giúp các số giống nhau nằm cạnh nhau → dễ skip trùng
   - Cho phép dùng two pointers

2. **Cố định `i`**, dùng `L` và `R` để tìm cặp có tổng = `-nums[i]`

3. `i`, `L`, `R` là **3 con trỏ** (chỉ số) trong cùng 1 mảng `nums`:
   - `i`: chạy từ 0 đến n-3
   - `L = i+1`: chạy từ trái sang phải
   - `R = n-1`: chạy từ phải sang trái

---

## Code

```go
func threeSum(nums []int) [][]int {
    sort.Ints(nums)
    res := [][]int{}
    i := 0
    for i < len(nums)-2 {
        // Skip trùng i (quan trọng!)
        if i > 0 && nums[i] == nums[i-1] {
            i++
            continue
        }
        // Nếu nums[i] > 0 thì dừng (các số sau đều dương)
        if nums[i] > 0 {
            break
        }
        l, r := i+1, len(nums)-1
        for l < r {
            sum := nums[i] + nums[l] + nums[r]
            if sum < 0 {
                l++       // tổng nhỏ, cần số lớn hơn
            } else if sum > 0 {
                r--       // tổng lớn, cần số nhỏ hơn
            } else {
                // sum == 0: tìm thấy 1 bộ
                res = append(res, []int{nums[i], nums[l], nums[r]})
                l++
                r--
                // Skip trùng L và R
                for l < r && nums[l] == nums[l-1] { l++ }
                for l < r && nums[r] == nums[r+1] { r-- }
            }
        }
        i++
    }
    return res
}
```

---

## Trace tay từng ví dụ

### Trace 1: `nums = [-1,0,1,2,-1,-4]`

#### Bước 0: Sort

```
nums = [-4, -1, -1, 0, 1, 2]
index    0    1   2  3  4  5
```

---

#### Bước 1: i=0, nums[0] = -4

Kiểm tra:
- `i > 0 && nums[i] == nums[i-1]` → i=0 nên bỏ qua
- `nums[i] > 0`? -4 > 0? → sai → không break

Đặt L = 1, R = 5. Cần tìm L + R = 4 (vì -4 + L + R = 0)

| Lần | L | R | nums[L] | nums[R] | tổng L+R | So với 4 | Hành động |
|-----|---|----|---------|---------|----------|----------|-----------|
| 1 | 1 | 5 | -1 | 2 | 1 | < 4 | L++ (L=2) |
| 2 | 2 | 5 | -1 | 2 | 1 | < 4 | L++ (L=3) |
| 3 | 3 | 5 | 0 | 2 | 2 | < 4 | L++ (L=4) |
| 4 | 4 | 5 | 1 | 2 | 3 | < 4 | L++ (L=5) |
| 5 | 5 | 5 | - | - | - | - | L == R → hết |

**Kết quả i=0:** Không tìm được bộ nào
**i++ → i=1**

---

#### Bước 2: i=1, nums[1] = -1

Kiểm tra:
- `i > 0 && nums[1] == nums[0]`? -1 == -4? → sai → không skip
- `nums[i] > 0`? -1 > 0? → sai → không break

Đặt L = 2, R = 5. Cần tìm L + R = 1 (vì -1 + L + R = 0)

| Lần | L | R | nums[L] | nums[R] | tổng L+R | So với 1 | Hành động |
|-----|---|----|---------|---------|----------|----------|-----------|
| 1 | 2 | 5 | -1 | 2 | 1 | **= 1** | **Thêm [-1,-1,2]**, L++, R-- (L=3, R=4) |
| 2 | 3 | 4 | 0 | 1 | 1 | **= 1** | **Thêm [-1,0,1]**, L++, R-- (L=4, R=3) |

L=4 > R=3 → hết

**res hiện tại:** `[[-1,-1,2], [-1,0,1]]`
**i++ → i=2**

---

#### Bước 3: i=2, nums[2] = -1

Kiểm tra:
- `i > 0 && nums[2] == nums[1]`? -1 == -1? → **có → SKIP** (i++ → i=3)

**Nếu KHÔNG skip (sai):**
L=3, R=5. Cần L+R=1:

| Lần | L | R | nums[L] | nums[R] | tổng L+R | Hành động |
|-----|---|----|---------|---------|----------|-----------|
| 1 | 3 | 5 | 0 | 2 | 2 > 1 | R-- (R=4) |
| 2 | 3 | 4 | 0 | 1 | **= 1** | **Thêm [-1,0,1] LẦN 2 → TRÙNG!** |

→ Nếu không skip, kết quả sai: `[[-1,-1,2], [-1,0,1], [-1,0,1]]`

---

#### Bước 4: i=3, nums[3] = 0

Kiểm tra:
- `nums[3] == nums[2]`? 0 == -1? → sai → không skip
- `nums[i] > 0`? 0 > 0? → sai → không break

Đặt L=4, R=5. Cần L+R=0 (vì 0 + L + R = 0)

| Lần | L | R | nums[L] | nums[R] | tổng L+R | Hành động |
|-----|---|----|---------|---------|----------|-----------|
| 1 | 4 | 5 | 1 | 2 | 3 > 0 | R-- (R=4) |
| 2 | 4 | 4 | - | - | - | L == R → hết |

**Kết quả i=3:** Không tìm được
**i++ → i=4**

---

#### Bước 5: i=4, nums[4] = 1

- `nums[i] > 0`? 1 > 0? → **có → BREAK**

---

#### Kết quả cuối cùng:
```
[[-1,-1,2], [-1,0,1]]
```

✅ **Đúng**

---

### Trace 2: `nums = [0,1,1]`

#### Bước 0: Sort (giữ nguyên)

```
nums = [0, 1, 1]
index   0  1  2
```

n=3, n-2=1, nên i chỉ chạy đến i < 1 → i=0

#### Bước 1: i=0, nums[0]=0

L=1, R=2. Cần L+R=0

| Lần | L | R | nums[L] | nums[R] | tổng L+R | Hành động |
|-----|---|----|---------|---------|----------|-----------|
| 1 | 1 | 2 | 1 | 1 | 2 > 0 | R-- (R=1) |
| 2 | 1 | 1 | - | - | - | L == R → hết |

i++ → i=1, 1 < 1? sai → hết

**Kết quả:** `[]` ✅

---

### Trace 3: `nums = [0,0,0]`

#### Bước 0: Sort (giữ nguyên)

```
nums = [0, 0, 0]
index   0  1  2
```

n=3, i chỉ chạy i < 1 → i=0

#### Bước 1: i=0, nums[0]=0

L=1, R=2. Cần L+R=0

| Lần | L | R | nums[L] | nums[R] | tổng L+R | Hành động |
|-----|---|----|---------|---------|----------|-----------|
| 1 | 1 | 2 | 0 | 0 | **= 0** | **Thêm [0,0,0]**, L++, R-- (L=2, R=1) |

L=2 > R=1 → hết

**Kết quả:** `[[0,0,0]]` ✅

---

## Các khái niệm quan trọng

### 1. `i`, `L`, `R` là gì?

Là **số thứ tự của ô** (index), không phải giá trị trong ô.

```
nums = [-4, -1, -1, 0, 1, 2]
index    0    1   2  3  4  5
         ↑                   ↑
         i=0                 r=5
                  ↑
                 l=2
```

### 2. Tại sao cần `nums[i] > 0 { break }`?

Vì mảng đã sort tăng dần. Nếu `nums[i] > 0` thì các số sau nó cũng > 0. Tổng 3 số dương không thể = 0 → dừng.

### 3. Tại sao cần skip `nums[i] == nums[i-1]`?

Vì sort rồi, số giống nhau nằm cạnh nhau. Nếu `nums[i]` bằng `nums[i-1]`, thì tất cả bộ 3 bắt đầu bằng số này đã được xử lý bởi `i-1` rồi. Chạy tiếp chỉ **trùng lặp**.

### 4. Tại sao cần skip trùng L và R?

Sau khi tìm được 1 bộ, `l++` và `r--`. Nếu số mới của L giống số cũ, cặp (L, R) mới sẽ cho cùng kết quả → trùng.

### 5. Tại sao `i < len(nums)-2`?

Cần 3 chỉ số `i < L < R`. `R` tối đa là `n-1`, `L` tối thiểu là `i+1`. Nên `i` chạy đến `n-3` là cùng. `i < n-2` = `i <= n-3`.

```
n=6:
index: 0  1  2  3  4  5
                   i  L  R  ← i=3 là max còn 2 số phía sau
```

---

## Lỗi thường gặp: `i > 1` thay vì `i > 0`

### Sai:

```go
if i > 1 && nums[i] == nums[i-1] {  // SAI!
```

### Đúng:

```go
if i > 0 && nums[i] == nums[i-1] {  // ĐÚNG!
```

### Tại sao?

Ví dụ `[0,0,0,0]` sort: `[0,0,0,0]`

| i | nums[i] | i > 1? | kết quả |
|---|---------|--------|---------|
| 0 | 0 | `i > 1` = false | chạy bình thường → thêm [0,0,0] |
| 1 | 0 | `i > 1` = **false** (1 không > 1) | **KHÔNG skip** → thêm [0,0,0] nữa → TRÙNG |
| 2 | 0 | `i > 1` = true | skip |

→ Output sai: `[[0,0,0],[0,0,0]]`
→ Expected: `[[0,0,0]]`

Dùng `i > 0` thì i=1 bị skip ngay, chỉ còn 1 kết quả.

### Trace `[0,0,0,0]` với `i > 0` (đúng)

```
nums = [0, 0, 0, 0]
index   0   1   2   3
```

**i=0 (0):** L=1, R=3 → L+R=0

| L | R | nums[L]+nums[R] | Hành động |
|---|---|-----------------|-----------|
| 1 | 3 | 0+0 = 0 | Thêm [0,0,0], L=2, R=2 → hết |

**i=1 (0):** nums[1]==nums[0] → **SKIP** (i>0 && bằng nhau)

**i=2 (0):** i < len-2? 2 < 2? sai → hết

Kết quả: `[[0,0,0]]` ✅

---

## So sánh 2Sum vs 3Sum

| Bài | Cách làm | Time | Space | Tại sao? |
|-----|----------|------|-------|----------|
| 2Sum | Hash map | O(n) | O(n) | Chỉ cần 1 cặp, không cần dedup |
| 3Sum | Sort + 2 pointers | O(n²) | O(1) | Dedup miễn phí nhờ sort, tránh hash map rườm rà |
