(async () => {
  const searchParams = new URLSearchParams(location.search);
  const contractAddress = searchParams.get("addr");
  const tokenId = searchParams.get("tokenid");
  const block = searchParams.get("block");
  const timestamp = searchParams.get("timestamp");

  const web3 = new Web3("https://polygon-rpc.com");
  const Contract = new web3.eth.Contract(abi, contractAddress);

  const counter = await Contract.methods.getokenTransferCount(tokenId).call();
  const balance = await Contract.methods.totalSupply().call();
  const startBlock = await Contract.methods.getStartBlock().call();
  const tokenName = await Contract.methods.name().call();
  const owner = await Contract.methods.ownerOf(tokenId).call();

  $("#contractId").text(contractAddress);
  $("#tokenId").text(tokenId);
  $("#tokenCount").text(counter + "回");
  $("#balance").text(balance + "NFTs");
  $("#startBlock").text(startBlock);
  $("#block").text(block);
  $("#name").text(tokenName);
  $("#owner").text(owner);
  $("#timestamp").text(timestamp);
})();
