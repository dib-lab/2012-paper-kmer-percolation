all: kmer-percolation.pdf

clean:
	rm -fr *.log *.aux kmer-percolation.pdf

kmer-percolation.pdf: kmer-percolation.tex
	pdflatex kmer-percolation
	bibtex kmer-percolation
	pdflatex kmer-percolation
	pdflatex kmer-percolation
