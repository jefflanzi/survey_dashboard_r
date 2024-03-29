##load required packages
library(magrittr)
library(dplyr)
library(tidyr)

# wrapper function for selecting table type depending on q_types as defined in qtypes.csv
# spread == FALSE allows passing long form data to svy_plot function
svy_table <- function(data, qid, segment = "overall", freq = FALSE, spread = TRUE) {
        
        
        #summarise data
        qtype <- q_types[q_types$qid == qid, "qtype"]
        qtable <- switch(qtype,
                         word_cloud = Word_count(data, qid, segment),
                         single_choice = single_choice(data, qid, segment, freq),
                         multiple_choice = multiple_choice(data, qid, segment, freq),
                         likert_sum = likert_sum(data, qid, segment, freq),
                         likert_avg = likert_avg(data, qid, segment, freq),
                         dual_scale = dual_scale(data, qid, segment, freq),
                         array_count = array_count(data, qid, segment, freq),
                         free_text = free_text(data, qid, segment),
                         numeric_input = numeric_input(data, qid, segment),
                         #nps = single_choice(...),
                         stop(paste("invalid question type:", qid, qtype))
        )
        
        if (spread == TRUE & !qtype %in% c("free_text", "word_cloud")) {
                qtable %<>% spread(segment, value, fill = 0, drop = F)
        }
        
        return(qtable)
}

# raw frequencies/percentages table
single_choice <- function(data, qid, segment = "overall", freq = FALSE) {
        
        if (segment == qid) {stop("Question and Segment cannot have the same input")}
        
        #gather question and segment columns
        qdata <- qmelt(data, qid, segment)
        
        # summarise data from long form        
        qtable <- qdata %>%         
                group_by(segment, answer) %>%
                summarise(value = length(answer)) %>%
                #rename answer to sq to stay consistent with other tables
                rename(sq = answer)
        
        # calculate percentages if pct == TRUE
        if (freq == FALSE) {
                qtable %<>%
                        group_by(segment) %>%
                        mutate(value = round(value/sum(value), 3))
        }
        
        return(qtable)        
}

multiple_choice <- function(qdata, qid, segment = "overall", freq = FALSE) {
        
        #gather question and segment columns
        qdata <- qmelt(data, qid, segment)
        
        qtable <- qdata %>%
                group_by(segment, sq) %>%
                summarise(value = sum(answer == "Yes")) %>%
                arrange(desc(value))
        
}

# average rating
likert_avg <- function(data, qid, segment = "overall", freq = FALSE) {
        
        #gather question and segment columns
        qdata <- qmelt(data, qid, segment)
        
        qtable <- qdata %>%
                group_by(segment, sq) %>%
                summarise(value = round(mean(as.numeric(answer)), 2))
        
        #sort based on overall average
        sqorder <- qtable %>% group_by(sq) %>%
                summarise(value = mean(value)) %>%
                arrange(value)
        
        qtable %<>% mutate(sq = factor(sq, levels = sqorder$sq))
        
        return(qtable)
}

# percentage of agreement
likert_sum <- function(data, qid, segment = "overall", freq = FALSE) {
        
        #gather question and segment columns
        qdata <- qmelt(data, qid, segment)
        
        qtable <- qdata %>% 
                group_by(segment, sq) %>%
                summarise(value = round(sum(grepl(likert_pos, answer))/length(sq), 3)) %>%
                arrange(segment, desc(value))
        
        return(qtable)        
}

array_count <- function(data, qid, segment = "overall", freq = FALSE) {
        
        #gather question and segment columns
        qdata <- qmelt(data, qid, segment)
        
        qtable <- qdata %>%
                group_by(sq, answer) %>%
                summarise(value = n())
        
        return(qtable)        
}

dual_scale <- function(data, qid, segment = "overall", freq = FALSE) {
        # gather question and segment columns
        qdata <- qmelt(data, qid, segment, sqlabs = FALSE)
        
        # summarize
        qtable <- qdata %>%
                group_by(segment, sq, answer) %>%
                summarise(value = n())
        
        return(qtable)
}

# generate word counts from raw text
Word_count <- function(data, qid, segment = "overall") {
        
        #gather question and segment columns
        qdata <- qmelt(data, qid, segment)
        
        library(tm)
        
        #transform the text
        words <- tolower(qdata$answer)
        words <- removePunctuation(words)
        words <- removeWords(words, stopwords("english"))
        words <- stripWhitespace(words)
        
        #create a corpus
        c <- Corpus(VectorSource(words))
        
        #matrix of individual words
        tdm <- TermDocumentMatrix(c)
        m <- as.matrix(tdm)
        
        #word counts
        data.frame(sort(rowSums(m), decreasing = T))    
}

#dump free text
free_text <- function(data, qid, segment) {
        
        #gather question and segment columns
        select(data, q_cols(c("id", qid, segment))) %>%
                rename_("segment" = segment) %>%
                gather(sq, answer, -c(id, segment), na.rm = T) %>%
                arrange(desc(segment, id))
        
}

numeric_input <- function(data, qid, segment = "overall", freq = FALSE) {
        # gather question data
        qdata <- qmelt(data, qid, segment)
        
        # summarise
        qtable <- qdata %>%
                group_by(segment) %>%
                mutate(cuts = cut(answer, breaks = c(-1,25,50,75,100),
                                   labels = c("0-25%", "25-50%", "50-75%", "75-100%"))) %>%
                group_by(segment, cuts) %>%
                summarise(value = length(cuts))              
                
                # alternate numeric summary
#                 summarise(mean = mean(answer),
#                           min = min(answer),
#                           max = max(answer),
#                           SD = sd(answer)) %>%
#                 gather(measure, value, -segment)

        return(qtable)
}
