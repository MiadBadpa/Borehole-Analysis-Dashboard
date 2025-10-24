# 🪨 Advanced Borehole Analysis and Visualization Dashboard (v4.2)

**Author:** Miad Badpa  
**Language:** MATLAB  
**Version:** 4.2  
**License:** MIT  

---

## 📖 Overview
This MATLAB script provides a comprehensive dashboard for **borehole data visualization** and **core image integration**.  
It allows geologists to interactively map, visualize, and annotate borehole logs including lithology, alteration, texture, and mineralization data.

---

## ✨ Key Features
✅ Automatic core photo mapping from filenames (e.g., `0-7.5.jpg`)  
✅ Dynamic plotting for multiple categorical logs (e.g., Rock_Type, Alteration, Texture, Minerals)  
✅ Support for geological pattern textures (e.g., Granite.png, Andesite.png)  
✅ Real-time annotation mode for linking images, PDFs, or notes to core sections  
✅ Depth-down visualization with synchronized axes for all plots  
✅ Robust Excel import with automatic header detection and data cleaning  

---

## 🧩 Input Files
| File Type | Example | Description |
|------------|----------|-------------|
| Excel File | `BH181.xlsx` | Contains borehole logs (From, To, Rock_Type, Alteration, etc.) |
| Core Photos | `0-7.5.jpg`, `7.5-15.jpg` | Core box photos named by depth intervals |
| Pattern Images | `Granite.png`, `Limestone.png` | Used as fill patterns for lithological logs |

---

## 🧠 Usage
1. Run the script in MATLAB:  
   ```matlab
   Advanced_Borehole_Analysis_v4_2
