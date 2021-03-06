dirpath <- "."

# grab founder SNPs from the Sanger VCF file
# and place in sqlite database
# sqlite stuff following tutorial at
#     http://sandymuspratt.blogspot.com/2012/11/r-and-sqlite-part-1.html

# At Sanger:
# ftp://ftp-mouse.sanger.ac.uk/current_snps
#     ftp://ftp-mouse.sanger.ac.uk/current_snps/mgp.v5.merged.snps_all.dbSNP142.vcf.gz
#     ftp://ftp-mouse.sanger.ac.uk/current_snps/mgp.v5.merged.snps_all.dbSNP142.vcf.gz.tbi
#
# Same files, at JAX:
# ftp://ftp.jax.org/SNPtools/variants/
#     ftp://ftp.jax.org/SNPtools/variants/mgp.v5.merged.snps_all.dbSNP142.vcf.gz
#     ftp://ftp.jax.org/SNPtools/variants/mgp.v5.merged.snps_all.dbSNP142.vcf.gz.tbi

chr <- c(1:19, "X")
cc_founders <- c("A/J", "C57BL/6J", "129S1/SvImJ", "NOD/ShiLtJ", "NZO/HlLtJ",
                 "CAST/EiJ", "PWK/PhJ", "WSB/EiJ")
strains <- sub("/", "_", cc_founders[-2])
n_strains <- length(strains)
file <- file.path(dirpath, "RawData/mgp.v5.merged.snps_all.dbSNP142.vcf.gz")

library(VariantAnnotation)

library(RSQLite)
db_file <- "./ccfoundersnps.sqlite"
db <- dbConnect(SQLite(), dbname=db_file)
dbGetQuery(db, paste0("ATTACH '", db_file, "' AS NEW"))

db_started <- FALSE
for(thechr in chr) {
    for(left in seq(0, 190, by=10)) {
        cat(thechr, left, "\n")

        # 10 Mbp range
        gr <- GRanges(seqnames=thechr, ranges=IRanges(start=left*1e6, end=(left+10)*1e6-1))

        # grab data
        param <- ScanVcfParam(geno = c("GT", "FI"), samples = strains,
                              which = gr)
        snps <- readVcf(file = file, genome = "mm10", param = param)
        if(nrow(snps)==0) next

        # drop snps with any quality < 1
        fi <- geno(snps)$FI
        snps <- snps[rowSums(!is.na(fi) & fi==1) == n_strains]

        # drop snps that are all 0/0
        g <- geno(snps)$GT
        snps <- snps[rowSums(is.na(g)) == 0 & rowSums(g=="0/0") < n_strains]

        # convert to 1/2
        g <- (geno(snps)$GT != "0/0") + 1 # convert 0/0 -> 1 (1/1, 2/2, 3/3) -> 2
        cat("    ", nrow(g), "snps\n")
        if(nrow(snps)==0) next

        # add B6 genotypes (reference) and change column names
        g <- cbind(g[,1,drop=FALSE], B6=1, g[,-1])
        colnames(g) <- cc_founders

        # convert so that 1 is the most common allele
        # (on second thought, I see no point in this)
        ### num2 <- rowSums(g==2)
        ### g[num2 > 4] <- 3-g[num2>4]

	# Consequence. Reverse engineered. Likely fragile.
	csq <- sapply(info(snps)$CSQ, function(x) {
	    x <- strsplit(x, "|", fixed=TRUE)[[1]]
	    ensembl <- x[2]
	    csq <- gsub("&",",",x[5],fixed=TRUE)
	    c(ensembl, csq)
	})

        # create full table of info
        snps <- data.frame(snp_id=rownames(g),
                           chr=as.vector(seqnames(snps)),
                           pos_Mbp=start(snps)/10^6,
                           alleles=paste(as.vector(ref(snps)),
                                         unstrsplit(CharacterList(alt(snps)), sep="/"), sep="|"),
                           sdp=apply(g-1, 1, function(a) sum(a*2^(seq(along=a)-1))),
			   ensembl_gene=csq[1,],
                           csq=csq[2,],
                           stringsAsFactors=FALSE)

        dbWriteTable(db, "snps", snps, row.names=FALSE, overwrite=!db_started,
                     append=db_started, field.types=NULL)
        db_started <- TRUE

    }
}

dbGetQuery(db, "CREATE INDEX chr_pos ON snps(chr, pos_Mbp)")
