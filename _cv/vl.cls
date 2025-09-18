\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{vl}[21/4/2021 0.1.0 Template for my documents]
\LoadClass[11pt]{article}
\RequirePackage{xcolor}
\definecolor{vl-color}{RGB}{47, 52, 63}
\RequirePackage{graphicx}
\RequirePackage{microtype}
\RequirePackage{libertine}
\RequirePackage{paralist}
\RequirePackage[absolute]{textpos}
\TPGrid{16}{16}
\RequirePackage[top=2\TPVertModule, bottom=2\TPVertModule, left=3\TPHorizModule, right=2\TPHorizModule]{geometry}
\RequirePackage{tikz}
\RequirePackage{fancyhdr}
\pagestyle{fancy}
\renewcommand{\headrulewidth}{0pt}
\fancyhf{}
\fancyfoot[C]{{
    \ifnum\value{page}=1\else
    \color{gray} page \thepage{} of \pageref{LastPage}
    \fi
}}
\fancyfoot[C]{
    \begin{textblock}{2}(0,0){
        \tikz[x=\TPHorizModule,y=\TPVertModule] \filldraw[fill=vl-color, draw=none] (0,0) rectangle (2,16);
    }\end{textblock}
}

\RequirePackage[normalem]{ulem}
\RequirePackage[hidelinks]{hyperref}
\makeatletter\begingroup
\catcode`\$=6
\catcode`\#=12
\gdef\href@split$1#$2#$3\\$4{\hyper@@link{$1}{$2}{\uline{$4}}\endgroup}
\endgroup\makeatother

\newcommand\nospell[1]{#1}

\AtBeginDocument{%
\setlength{\topskip}{0mm}
\setlength{\parindent}{0pt}
\setlength{\parskip}{4pt}
\tolerance=2000
\raggedbottom
\large
}

\newcommand\vlPrintPhoto{
\begin{textblock}{2.1}[1,1](14,3.5){
\includegraphics[width=\textwidth]{avatar.jpg}
}\end{textblock}
}

\endinput
