"""
Plotly chart configurations and helper functions
"""

import plotly.express as px

# Color schemes
NYT_COLORS = {
    "primary": "#121212",  # NYT black
    "secondary": "#666666",  # Gray
    "accent": "#326891",  # NYT blue
    "highlight": "#D0021B",  # NYT red
    "success": "#2E7D32",  # Green
    "warning": "#F57C00",  # Orange
}

# Color palette for multi-series charts
COLOR_PALETTE = [
    "#326891",
    "#D0021B",
    "#2E7D32",
    "#F57C00",
    "#7B1FA2",
    "#0097A7",
    "#C62828",
    "#558B2F",
]


def create_line_chart(df, x, y, title, color=None, height=400):
    """Create a line chart with NYT styling"""
    if color:
        fig = px.line(df, x=x, y=y, color=color, title=title, height=height)
    else:
        fig = px.line(df, x=x, y=y, title=title, height=height)

    fig.update_layout(
        font_family="Georgia, serif",
        title_font_size=20,
        hovermode="x unified",
        plot_bgcolor="white",
    )
    fig.update_xaxes(showgrid=True, gridcolor="#f0f0f0")
    fig.update_yaxes(showgrid=True, gridcolor="#f0f0f0")

    return fig


def create_bar_chart(df, x, y, title, orientation="v", color=None, height=400):
    """Create a bar chart with NYT styling"""
    if color:
        fig = px.bar(df, x=x, y=y, color=color, title=title, orientation=orientation, height=height)
    else:
        fig = px.bar(
            df,
            x=x,
            y=y,
            title=title,
            orientation=orientation,
            height=height,
            color_discrete_sequence=[NYT_COLORS["accent"]],
        )

    fig.update_layout(
        font_family="Georgia, serif",
        title_font_size=20,
        plot_bgcolor="white",
    )
    fig.update_xaxes(showgrid=False)
    fig.update_yaxes(showgrid=True, gridcolor="#f0f0f0")

    return fig
