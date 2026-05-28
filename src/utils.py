import matplotlib.pyplot as plt
import matplotlib

def get_fig_dim(width, fraction=1, aspect_ratio=None):
    """Set figure dimensions to avoid scaling in LaTeX.

    Parameters
    ----------
    width: float
            Document textwidth or columnwidth in pts
    fraction: float, optional
            Fraction of the width which you wish the figure to occupy
    aspect_ratio: float, optional
            Aspect ratio of the figure

    Returns
    -------
    fig_dim: tuple
            Dimensions of figure in inches
    """
    # Width of figure (in pts)
    fig_width_pt = width * fraction

    # Convert from pt to inches
    inches_per_pt = 1 / 72.27

    if aspect_ratio is None:
        # If not specified, set the aspect ratio equal to the Golden ratio (https://en.wikipedia.org/wiki/Golden_ratio)
        aspect_ratio = (1 + 5**.5) / 2

    # Figure width in inches
    fig_width_in = fig_width_pt * inches_per_pt
    # Figure height in inches
    fig_height_in = fig_width_in / aspect_ratio

    fig_dim = (fig_width_in, fig_height_in)

    return fig_dim


def latexify(font_serif='Computer Modern', mathtext_font='cm', font_size=10, small_font_size=None, usetex=True, use_defaults=False):
    """Set up matplotlib's RC params for LaTeX plotting."""

    if use_defaults:
        matplotlib.rcParams.update(matplotlib.rcParamsDefault)
        plt.rcParams.update(plt.rcParamsDefault)
        return

    if small_font_size is None:
        small_font_size = font_size

    # Get available fonts
    import matplotlib.font_manager as fm
    available_fonts = {f.name for f in fm.fontManager.ttflist}

    # Define fallback chains for common font families
    font_fallbacks = {
        'Times New Roman': ['Times New Roman', 'Times', 'Liberation Serif', 'DejaVu Serif'],
        'Computer Modern': ['Computer Modern', 'CMU Serif', 'Latin Modern Roman', 'cmr10'],
        'Arial': ['Arial', 'Liberation Sans', 'DejaVu Sans'],
    }

    # Try to find the best available font
    actual_font = font_serif
    if font_serif in font_fallbacks:
        # Try each fallback in order
        for fallback in font_fallbacks[font_serif]:
            if fallback in available_fonts:
                actual_font = fallback
                # Only print message if not using LaTeX and had to fall back
                if fallback != font_serif and not usetex:
                    print(f"Font '{font_serif}' not found, using '{actual_font}' instead")
                break
        else:
            if not usetex:
                print(f"Warning: Neither '{font_serif}' nor fallbacks found. Using default.")
    elif font_serif not in available_fonts and not usetex:
        print(f"Warning: Font '{font_serif}' not found. Using default.")

    params = {
        'backend': 'ps',
        'text.latex.preamble': r'\usepackage{gensymb} \usepackage{bm}',

        'axes.labelsize': font_size,
        'axes.titlesize': font_size,
        'font.size': font_size,

        # Optionally set a smaller font size for legends and tick labels
        'legend.fontsize': small_font_size,
        'legend.title_fontsize': small_font_size,
        'xtick.labelsize': small_font_size,
        'ytick.labelsize': small_font_size,

        'text.usetex': usetex,
        'font.family': 'serif',
        'mathtext.fontset': mathtext_font
    }

    # Only set font.serif if not using LaTeX (LaTeX handles fonts itself)
    if not usetex:
        params['font.serif'] = actual_font

    # Fix the mathtext warning
    if not usetex and 'cm' in actual_font.lower():
        params['axes.formatter.use_mathtext'] = True

    matplotlib.rcParams.update(params)
    plt.rcParams.update(params)
