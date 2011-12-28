all: kmer-percolation.pdf

clean:
	rm -fr *.log *.aux kmer-percolation.pdf

kmer-percolation.pdf: kmer-percolation.tex
	pdflatex kmer-percolation
	#	bibtex kmer-percolation
	pdflatex kmer-percolation
	pdflatex kmer-percolation

tar:
	tar czvf kmer-percolation.tar.gz kmer-percolation.tex bloomgraph.pdf f3b*.pdf newclust.pdf newdiam.pdf newpart.pdf s1.pdf pnastwo.cls pnastwof.sty
