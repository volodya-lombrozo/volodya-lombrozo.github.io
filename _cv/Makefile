TEXS=$(wildcard *.tex)
PDFS=$(TEXS:.tex=.pdf)

all: $(PDFS)

clean:
	rm -rf .DS_Store *.aux *.bbl *.bcf *.blg *.fdb_latexmk *.fls *.log *.run.xml *.out
	rm -rf $(PDFS)
	rm -rf _minted*

%.pdf: %.tex vl.cls aspell.en.pws
	latexmk -pdf $<
	texqc --ignore 'You have requested document class' $<
	texsc $<