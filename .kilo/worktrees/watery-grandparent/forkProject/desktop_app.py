import flet as ft
import dataset
import calculation as calc
import optimizer
import pandas as pd
from datetime import datetime

# --- Theme Constants (Based on your style.css) ---
BG_COLOR = "#0f172a"        # Slate 950
SIDEBAR_COLOR = "#1e293b"   # Slate 800
ACCENT_COLOR = "#22d3ee"    # Cyan 400
TEXT_COLOR = "#e2e8f0"      # Slate 200

def main(page: ft.Page):
    # 1. Page Configuration
    page.title = "SpecFinder Pro - Desktop Edition"
    page.theme_mode = ft.ThemeMode.DARK
    page.padding = 0
    page.bgcolor = BG_COLOR
    page.window_width = 1200
    page.window_height = 800
    
    # State Management (Replacing st.session_state)
    state = {
        "items": [],
        "database": [],
        "container_size": "20ft" # Default
    }

    # Load Database (Replicating app.py logic)
    if hasattr(dataset, 'get_data'):
        state["database"] = dataset.get_data()
    elif hasattr(dataset, 'STATIC_DATABASE'):
        state["database"] = dataset.STATIC_DATABASE
    else:
        state["database"] = []

    # --- UI Components ---

    # 1. Inputs
    txt_width = ft.TextField(label="Width (mm)", width=100, text_size=12, border_color=ft.colors.GREY_700)
    txt_length = ft.TextField(label="Length (mm)", width=100, text_size=12, border_color=ft.colors.GREY_700)
    txt_height = ft.TextField(label="Height (mm)", width=100, text_size=12, border_color=ft.colors.GREY_700)
    txt_code = ft.TextField(label="Product Code", expand=True, text_size=12, border_color=ft.colors.GREY_700)
    txt_qty = ft.TextField(label="Qty", width=80, value="1", text_size=12, border_color=ft.colors.GREY_700)
    
    # Dropdown for container type
    dd_container = ft.Dropdown(
        width=200,
        options=[
            ft.dropdown.Option("20ft", "20ft Container (5.9m)"),
            ft.dropdown.Option("40ft", "40ft Container (12m)"),
        ],
        value="20ft",
        label="Container Size",
        border_color=ACCENT_COLOR
    )

    # 2. Data Table
    items_table = ft.DataTable(
        columns=[
            ft.DataColumn(ft.Text("Code")),
            ft.DataColumn(ft.Text("Dim (WxLxH)")),
            ft.DataColumn(ft.Text("Qty")),
            ft.DataColumn(ft.Text("Weight/Unit")),
            ft.DataColumn(ft.Text("Total Wt")),
            ft.DataColumn(ft.Text("Action")),
        ],
        rows=[],
        border=ft.border.all(1, ft.colors.with_opacity(0.2, ft.colors.WHITE)),
        vertical_lines=ft.border.all(1, ft.colors.with_opacity(0.1, ft.colors.WHITE)),
        heading_row_color=ft.colors.with_opacity(0.1, ft.colors.WHITE),
    )

    # 3. Output Areas
    result_text = ft.Column()
    chart_container = ft.Container(content=ft.Text("Run Calculation to see 3D Plan", color=ft.colors.GREY_500))

    # --- Logic Functions ---

    def delete_item(e):
        index = e.control.data
        if 0 <= index < len(state["items"]):
            state["items"].pop(index)
            update_table()
            page.update()

    def update_table():
        items_table.rows.clear()
        for idx, item in enumerate(state["items"]):
            items_table.rows.append(
                ft.DataRow(
                    cells=[
                        ft.DataCell(ft.Text(item['code'])),
                        ft.DataCell(ft.Text(f"{item['width']}x{item['length']}x{item['height']}")),
                        ft.DataCell(ft.Text(str(item['quantity']))),
                        ft.DataCell(ft.Text(f"{item['unit_wt']:.2f}")),
                        ft.DataCell(ft.Text(f"{item['grand_total']:.2f}")),
                        ft.DataCell(
                            ft.IconButton(
                                icon=ft.icons.DELETE, 
                                icon_color="red", 
                                data=idx, 
                                on_click=delete_item
                            )
                        ),
                    ]
                )
            )
        page.update()

    def add_item_click(e):
        try:
            # Inputs
            w = float(txt_width.value)
            l = float(txt_length.value)
            h = float(txt_height.value)
            q = int(txt_qty.value)
            c = txt_code.value
            
            # Use calculation.py logic
            # Note: We need standard side_cover/metal_thk/plate_count. 
            # In a full app, these should be inputs too, but setting defaults for now based on context.
            specs = calc.calculate_specs(
                width=w, length=l, height=h, code=c, quantity=q,
                side_cover=10, metal_thk=2, plate_count=2 # Defaults or add inputs for these
            )
            
            item_data = {
                "code": c, "width": w, "length": l, "height": h, "quantity": q,
                "unit_wt": specs['unit_wt'], "grand_total": specs['grand_total']
            }
            state["items"].append(item_data)
            
            # Clear inputs
            txt_code.value = ""
            txt_qty.value = "1"
            txt_code.focus()
            
            update_table()
            
        except ValueError:
            page.show_snack_bar(ft.SnackBar(content=ft.Text("Please enter valid numbers!")))

    def auto_fill_code(e):
        # Simple lookup in state["database"]
        code_query = txt_code.value.strip().upper()
        found = next((x for x in state["database"] if x['code'] == code_query), None)
        if found:
            txt_width.value = str(found['width'])
            txt_length.value = str(found['length'])
            txt_height.value = str(found['height'])
            page.update()

    txt_code.on_change = auto_fill_code

    def run_calculation(e):
        if not state["items"]:
            page.show_snack_bar(ft.SnackBar(content=ft.Text("No items to pack!")))
            return

        # Show loading
        chart_container.content = ft.ProgressBar(width=200, color=ACCENT_COLOR)
        page.update()

        # 1. Setup Container
        cont_type = dd_container.value
        # Approximate dimensions in cm (converted to match your unit logic)
        # Assuming your optimizer works in mm or cm. Adjust L/W/H below to match your optimizer units.
        if cont_type == "20ft":
            cont = optimizer.Container(length=5900, width=2350, height=2390, max_weight=28000) 
        else:
            cont = optimizer.Container(length=12030, width=2350, height=2390, max_weight=29000)

        # 2. Add Items to Optimizer
        items_to_pack = []
        for row in state["items"]:
            for _ in range(row['quantity']):
                # Create optimizer.Item objects
                it = optimizer.Item(
                    name=row['code'],
                    length=row['width'], # Mapping Width to Length depending on orientation logic
                    width=row['length'],
                    height=row['height'],
                    weight=row['unit_wt']
                )
                items_to_pack.append(it)

        # 3. Solve
        optimizer.pack_items_greedy(cont, items_to_pack) # Assuming function name from standard practices
        # NOTE: If your optimizer.py has a different function name (like solve()), change the line above.
        
        # 4. Get Statistics
        stats = optimizer.calculate_stats(cont) # Assuming this function exists based on snippet

        # 5. Display Stats
        result_text.controls = [
            ft.Text(f"Packed Items: {stats['packed_count']} / {len(items_to_pack)}", size=20, weight=ft.FontWeight.BOLD),
            ft.Text(f"Volume Utilization: {stats['volume_utilization']:.2f}%", color=ACCENT_COLOR),
            ft.Text(f"Total Weight: {stats['weight_total']:.0f} kg"),
            ft.ProgressBar(value=stats['weight_utilization']/100, color=ACCENT_COLOR, height=10),
        ]

        # 6. Display 3D Chart
        # Assuming optimizer has a function that returns a Plotly Figure
        # If your function is named differently (e.g., plot_container), change below.
        fig = optimizer.plot_container_3d(cont) 
        
        chart_container.content = ft.PlotlyChart(fig, expand=True, transparent=True)
        page.update()


    # --- Layout Assembly ---
    
    # Header
    header = ft.Container(
        content=ft.Row([
            ft.Icon(ft.icons.GRID_ON, size=30, color=ACCENT_COLOR),
            ft.Text("SpecFinder Pro", size=24, weight=ft.FontWeight.BOLD),
            ft.Container(expand=True),
            ft.Text("V1.0.0 Desktop", color=ft.colors.GREY_500)
        ], alignment=ft.MainAxisAlignment.START),
        padding=20,
        bgcolor=SIDEBAR_COLOR
    )

    # Sidebar Content
    sidebar_content = ft.Column([
        ft.Text("New Item Input", weight=ft.FontWeight.BOLD, color=ACCENT_COLOR),
        txt_code,
        ft.Row([txt_width, txt_length]),
        ft.Row([txt_height, txt_qty]),
        ft.ElevatedButton("Add to List", icon=ft.icons.ADD, on_click=add_item_click, bgcolor=ACCENT_COLOR, color="black", width=220),
        ft.Divider(color=ft.colors.GREY_800),
        ft.Text("Configuration", weight=ft.FontWeight.BOLD, color=ACCENT_COLOR),
        dd_container,
        ft.ElevatedButton("CALCULATE PLAN", icon=ft.icons.ROCKET_LAUNCH, on_click=run_calculation, height=50, width=220, bgcolor="green", color="white")
    ], spacing=15, scroll=ft.ScrollMode.AUTO)

    sidebar = ft.Container(
        content=sidebar_content,
        width=300,
        padding=20,
        bgcolor=SIDEBAR_COLOR,
        border=ft.border.only(right=ft.border.BorderSide(1, ft.colors.GREY_800))
    )

    # Main Content
    main_content = ft.Column([
        ft.Text("Packing List", size=18, weight=ft.FontWeight.W_600),
        ft.Container(content=items_table, height=250, border=ft.border.all(1, ft.colors.GREY_800), border_radius=10, padding=10, scroll=ft.ScrollMode.ALWAYS),
        ft.Divider(),
        ft.Text("Optimization Results", size=18, weight=ft.FontWeight.W_600),
        ft.Row([result_text], alignment=ft.MainAxisAlignment.CENTER),
        ft.Container(content=chart_container, expand=True, border=ft.border.all(1, ft.colors.GREY_800), border_radius=10)
    ], expand=True, padding=20)

    # Final Page Structure
    page.add(
        ft.Column([
            header,
            ft.Row([sidebar, main_content], expand=True)
        ], expand=True)
    )

if __name__ == "__main__":
    ft.app(target=main)