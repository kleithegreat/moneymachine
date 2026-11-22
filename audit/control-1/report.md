# Study 1, the positive control of the search

**Result: The agent's sessions end on a program that earns from the plant more often than G100's 100 evaluations do.**

Models that answered a counted session: claude-opus-5-5.

Markets counted: 43. Agent wins 15, losses 4, concordant 24.
Each rate's interval is the exact (Clopper-Pearson) 95% interval. Power is in architecture 5.3.

| Arm | Earned | Rate | 95% interval |
|---|---|---|---|
| Agent | 18/43 | 0.419 | 0.270 to 0.579 |
| G100 | 7/43 | 0.163 | 0.068 to 0.307 |

## Sessions by the set of ids that answered

The sets are not arms: which ids answer a session depends on how long it runs

| Ids | Sessions | Share | Earned | Rate | 95% interval |
|---|---|---|---|---|---|
| (no session) | 1 | 0.023 | 0/1 | 0.000 | 0.000 to 0.975 |
| claude-opus-5-5 | 42 | 0.977 | 18/42 | 0.429 | 0.277 to 0.590 |

## Markets

| Market | Evaluations | Ended | Model ids | Pairs won | Pick median | Reference median | Reads | Agent earns | G100 earns | G100 at the agent's count | G100 pairs won | G100 pick median | G100 reads |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| control-1-m000 | 0 | killed |  | None | None | None |  | False | True | None (False) | 48 | 0.5509974256405006 | funding, premium |
| control-1-m001 | 14 | finished | claude-opus-5-5 x71 | 56 | 0.772216468584744 | 1.0328502323107984 | funding | True | False | 0f3992c045520b2a41f654e26c45ae48fb1162975cc7e9d39be222830d2be48f (False) | 5 | -0.010371033776958832 | close, funding, high, premium |
| control-1-m002 | 9 | finished | claude-opus-5-5 x54 | 57 | 0.7688728886565036 | 1.0065634516383213 | funding | True | True | 4e5f1d6477bca91026d08cce599cbd5ba8bcfa56e52e360aba7805bcb2f6db6d (False) | 53 | 0.5981270152749438 | funding |
| control-1-m003 | 14 | finished | claude-opus-5-5 x72 | 0 | 0.05496878011262561 | 0.9911246996855767 | funding | False | False | 80b2e644255d03646632dd56568aee8afe37f32eed42daf317c9c0460c8fb77a (False) | 0 | 0.05354223979009423 | close, high, low |
| control-1-m004 | 9 | finished | claude-opus-5-5 x50 | 56 | 0.6478299307214157 | 1.0127073790946644 | funding | True | False | 1f99948a0952285137dc4c661f173ae033e2058ba7c29549dc673d70b2066866 (False) | 0 | 0.03550592272336073 | high |
| control-1-m005 | 13 | finished | claude-opus-5-5 x73 | 14 | 0.3753657064587289 | 1.0033128771461863 | close, funding | False | False | 4065102ccceaf6266d660b83d0505ca142c1a1ea292bbf959456047ba68c5046 (False) | 9 | 0.04174703869145169 | high |
| control-1-m006 | 9 | finished | claude-opus-5-5 x63 | 1 | -0.09023111302045894 | 1.03416604083565 | close | False | False | a07657c791e13c1ecb70b1bfb2c65f24f2c89592c54a2d7d0aee19f499d4e76f (False) | 0 | -0.5158183370267835 | premium |
| control-1-m007 | 11 | finished | claude-opus-5-5 x58 | 3 | 0.36056815535866804 | 1.0268296160186832 | close, premium | False | False | 80b2e644255d03646632dd56568aee8afe37f32eed42daf317c9c0460c8fb77a (False) | 0 | 0.03577621014829335 | close, high, low |
| control-1-m008 | 9 | finished | claude-opus-5-5 x60 | 0 | 0.0005424458747699257 | 1.0016472520286162 | close | False | False | 1f53a2154d581c7a751c93b21b0c2081a3527838bd979b726d292da1387f5a76 (False) | 0 | 0.26259713740804735 | close, funding, high, low |
| control-1-m009 | 14 | finished | claude-opus-5-5 x71 | 0 | 0.17388096581799162 | 1.0207576876991495 | close, funding | False | False | fb224c594b33d4561279a20d89f87a93e44e67c65e658b16d6aedc5423a2ec93 (False) | 0 | -0.03568021224113249 | close, high, low |
| control-1-m010 | 11 | finished | claude-opus-5-5 x53 | 26 | 0.49767684740937823 | 1.0183196550438363 | funding | False | True | 664b0d07de2c7805ef802b830c517682ae50cd8ce66d6b134e317545d9dd1900 (False) | 57 | 0.8276594245305735 | funding |
| control-1-m011 | 7 | finished | claude-opus-5-5 x38 | 24 | 0.5051997858432872 | 1.0200033189593387 | close, funding, open | False | False | ed8b3934089acd8d03039b7634d4aede51d2a005830050543f9f092452edfdb0 (False) | 0 | -0.08355148567690711 | close, high, low, premium |
| control-1-m012 | 5 | finished | claude-opus-5-5 x31 | 57 | 1.0384143772615966 | 0.9667402274151825 | funding | True | False | eb48d7be2d3b5752c87bc6cb2d848701b8fe5f0eb5b767c0cc40d3e417cdad1d (False) | 0 | 0.027010061094874527 | low |
| control-1-m013 | 10 | finished | claude-opus-5-5 x61 | 0 | 0.030895425017843148 | 0.9861630108765178 | close | False | False | 09058d151e315e5467df6e8a754b6fa6b053e85f47804d8206d3b4101d088539 (False) | 0 | 0.022328137082236965 | high |
| control-1-m014 | 12 | finished | claude-opus-5-5 x76 | 0 | 0.06452877697436443 | 1.005148978156097 | close | False | False | b5a141f8b4ae85135d6f110fd668d698af9f54dc0f76e92872d92e80ae4be2dc (False) | 0 | 0.37635307543297114 | funding, premium |
| control-1-m015 | 7 | finished | claude-opus-5-5 x39 | 0 | 0.0014028511844615954 | 0.988069726411996 | close, funding, open, volume | False | False | 88ba5a21e0bf1ba70ddb115ac5763360ff554e06466b474d073648003680b926 (False) | 0 | 0.06668832877533698 | close, high, low |
| control-1-m016 | 12 | finished | claude-opus-5-5 x66 | 0 | 0.00035953368428665033 | 1.0032843339814321 | close, funding, open | False | False | d45dc2e2da29f3241d6b96eec3fa25bab59af9858914f16e0c0eaad897894408 (False) | 0 | 0.061650774036747125 | high |
| control-1-m017 | 7 | finished | claude-opus-5-5 x40 | 57 | 1.0274160805603627 | 1.0312714727762375 | funding | True | False | 6d8d66afe6267869b7c8153141d350c0b6a564d915c98e1e77643d469760f4cc (False) | 30 | 0.5020030537710298 | premium |
| control-1-m018 | 8 | finished | claude-opus-5-5 x58 | 10 | 0.4305750183435535 | 1.0026545208034223 | premium | False | True | 22dba9cc172fe49fd04c7fb015adc1daaf8ab2e4148b3ff58d72d62a2488a457 (False) | 57 | 0.7877717908112574 | premium |
| control-1-m019 | 11 | finished | claude-opus-5-5 x62 | 0 | 0.2795358867580826 | 1.0292278991495714 | funding | False | False | 7ff9ceaa111b4607ace602409bfc685d9831ba025b502b6bdedbfa82328445c0 (False) | 0 | 0.051612548378762446 | close, high, low |
| control-1-m020 | 9 | finished | claude-opus-5-5 x53 | 0 | 0.014055483573590297 | 1.0170785658182537 | close, funding | False | False | 80b2e644255d03646632dd56568aee8afe37f32eed42daf317c9c0460c8fb77a (False) | 0 | 0.03586691540750042 | close, high, low |
| control-1-m021 | 10 | finished | claude-opus-5-5 x52 | 57 | 0.9080278004707089 | 1.0129708377237665 | funding | True | False | 7cfb56265a2d4d24a64ad3a09b4e43732b6d61c28be3d2d6defbe15c8b357446 (False) | 1 | 0.0 | close, high, low, premium |
| control-1-m022 | 8 | finished | claude-opus-5-5 x44 | 57 | 1.0599091943724215 | 1.0288319796168761 | funding | True | True | e723e3c55c44b55513421703e324a6e1cdfa99482301cce5150e661e9d6fca04 (True) | 57 | 0.7934249734195559 | close, high, low, premium |
| control-1-m023 | 10 | finished | claude-opus-5-5 x62 | 43 | 0.5318417620580618 | 1.032060357255988 | funding | True | False | 14198ec525a41182e944e4764f7176138028d19d5a34b1f83f1b3b0ea36555b9 (False) | 0 | 0.06212900533343965 | funding |
| control-1-m024 | 11 | finished | claude-opus-5-5 x70 | 57 | 1.2696611929280386 | 1.019134787305034 | funding | True | False | 96e0c4f42f3dacf4a4558699ff02bcbac8d2b514cbe3ae7f4cb024acc6ff5be1 (False) | 0 | -0.026266629381693635 | high |
| control-1-m025 | 7 | finished | claude-opus-5-5 x45 | 57 | 1.059407959963265 | 1.015393500021093 | funding | True | False | a29c6561ca1c61fa277d00223ac54bea644615be5c1a5fb056cb3ac038bf8979 (True) | 0 | 0.045481349683991104 | close, high, low |
| control-1-m026 | 10 | finished | claude-opus-5-5 x52 | 0 | 0.02864822941213596 | 1.0198286658223794 | close | False | False | 18b3804b31286951c75c27b8298d6c72c11fbb3531166158099df634a4b5e4b3 (False) | 0 | 0.03101260525792915 | low |
| control-1-m027 | 16 | finished | claude-opus-5-5 x96 | 2 | -0.00462678418982998 | 1.0245007889309043 | close | False | False | 5981861c3f48cee6ccd319756c0c66b7307f611d26d4e5ef09b87450c8ec8516 (False) | 0 | 0.020830133313726185 | open |
| control-1-m028 | 15 | finished | claude-opus-5-5 x74 | 0 | -0.09399086081785267 | 1.0115058350120336 | close, funding | False | False | 0cd56774954e502224d7622815a4a87b6baf2c9bc8d573e814c8715d2f7fe50d (False) | 1 | 0.02349196543433779 | close, funding, high, low |
| control-1-m029 | 14 | finished | claude-opus-5-5 x75 | 0 | -0.03459755864979375 | 1.0015318582346238 | close, funding | False | True | a9d518577beafdc0499b4a4f5c668e868f77db32c8f687e30a50e06373cfe3b5 (False) | 44 | 0.5457728275492983 | close, high, low, premium |
| control-1-m030 | 7 | finished | claude-opus-5-5 x43 | 57 | 0.9056829003086077 | 0.9873809928619268 | funding | True | False | 59b67aafbf77204000804733339cea2eb9e1a2641fcb523cd99c72e01026697b (False) | 25 | 0.473825259375802 | close, funding, high, low |
| control-1-m031 | 9 | finished | claude-opus-5-5 x54 | 57 | 0.8307485290216182 | 1.0187254563442751 | funding | True | False | 430aad56acc8de664fddf3df1981acc4486a9b6e1333a2404a88e38bba2ece7c (False) | 29 | 0.5167495811750036 | funding, low |
| control-1-m032 | 15 | finished | claude-opus-5-5 x79 | 3 | 0.403604666884813 | 1.0228748753857542 | funding | False | False | 53ad9ac3fb9e88e35b8129d904ac7619bda37495bfe8ad5e63b4c13f37a21688 (False) | 10 | 0.4675026551524137 | premium |
| control-1-m033 | 9 | finished | claude-opus-5-5 x48 | 48 | 0.6070640476709106 | 1.0240461767069309 | funding | True | False | 62d4dff8370d025e3c1d41fb788931598221c313ab20d7db84daa7b167e26217 (False) | 0 | -0.03263336830130925 | close |
| control-1-m034 | 7 | finished | claude-opus-5-5 x39 | 56 | 0.5799139138787753 | 1.0268809366004596 | funding | True | False | 91c6e3203d57a97e491568bd38558efd5dc29c38412e72064f7a23704b7f9058 (False) | 0 | 0.10857573128085451 | close, funding, high, low, premium |
| control-1-m035 | 9 | finished | claude-opus-5-5 x53 | 46 | 0.559600967220884 | 1.0148334348435193 | funding | True | False | 33e12e7f9cabf48c416118a4bfc2434dbfc4b80b94e6d42c3534cedcd7de11d0 (False) | 0 | 0.0 | close, high, low, premium, volume |
| control-1-m036 | 8 | finished | claude-opus-5-5 x67 | 57 | 0.5951262536761968 | 0.9980313903302571 | premium | True | True | 1ad979a75694bc21e0c309e8de95c1bf6f019d876f1309c768e5c4932e99319a (False) | 57 | 0.787114358647443 | premium |
| control-1-m037 | 13 | finished | claude-opus-5-5 x63 | 0 | 0.02198704465949336 | 0.9889496698258178 | close | False | False | 1f4f7e7df22a55436196098c6377400626bf2aeec1989608df6f6e851b02c915 (False) | 1 | 0.0 | close, high, low |
| control-1-m038 | 12 | finished | claude-opus-5-5 x70 | 0 | 0.04625158107186689 | 0.9784793386226162 | close | False | False | 79488dacdec25c5f2c7c48938c2bd6eb6c9823372b8dd0fd865d8c9f74b2ed91 (False) | 0 | 0.02680454325782866 | close |
| control-1-m039 | 10 | finished | claude-opus-5-5 x48 | 2 | 0.3688101973741543 | 1.0283117081615654 | close, funding | False | False | 8b7e0703f2276069e808493ce7c883221c7a0157dbe456ffc28402a611664352 (True) | 0 | 0.04097249375551093 | high |
| control-1-m040 | 8 | finished | claude-opus-5-5 x48 | 0 | 0.009982648261961657 | 1.000540098037375 | close, funding, open, volume | False | False | a002cd3d071e6944f2200a4093c6035bf3678237b418a188e6f2a4a32f09f00f (False) | 1 | 0.04577051299924584 | close, high, low |
| control-1-m041 | 7 | finished | claude-opus-5-5 x45 | 57 | 0.786247495444782 | 1.0016321395484669 | funding | True | False | 81dbd4d2178c38d1c3e7e22f97e518c10b5a49fb9fa08b494600465fec76c4e3 (True) | 0 | 0.06249706747332766 | close, high, low |
| control-1-m042 | 8 | finished | claude-opus-5-5 x45 | 57 | 0.7298445684051688 | 1.0411160323719848 | funding | True | False | 7ff9ceaa111b4607ace602409bfc685d9831ba025b502b6bdedbfa82328445c0 (False) | 0 | 0.25827102672729507 | funding |

Sessions with no designed end: control-1-m000
